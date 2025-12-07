import os
import httpx
import logging as log
import pandas as pd
import asyncio
import aiohttp

os.environ["BASE_URL"] = "http://localhost:25500/v3"

httpx_logger = log.getLogger("httpx")
httpx_logger.setLevel(log.CRITICAL)
log.basicConfig(level=log.INFO, format="%(asctime)s - %(message)s")


def test_theta_data_connection():
    url = os.getenv("BASE_URL") + "/terminal/mdds/status"
    log.info(f"pinging url: {url}")
    response = httpx.get(url)
    service_restarted = False
    if response.text not in ["CONNECTED", "UNVERIFIED", "DISCONNECTED", "ERROR"]:
        log.warning(f"Theta Terminal: Connection status not known status's: {response.text[:100]}")
        # send_short_message(f"Theta Terminal: Connection status not known status's: {response.text[:100]}")
    if response.text != "CONNECTED":
        log.warning(f"Theta Terminal Connection Status: {response.text[:100]}, Restart the service.")
        # send_short_message(f"Theta Terminal Connection Status: {response.text[:100]}, Restart the service.")
        # web_hook = get_theta_redeploy_url()
        # if web_hook is not None:
        #     log.warning("Theta Connection UN-Healthy! Restarting Service!")
        #     response = httpx.get(web_hook)
        #     service_restarted = True
        #     if response.status_code == 200:
        #         send_short_message("Theta Terminal Connection Restarted Successfully!")
        #     else:
        #         send_error_message(response.text)
        # else:
        #     log.warning("Theta Connection UN-Healthy! No Web-hook supplied to restart service!")
    else:
        log.info("Theta Connection Healthy!")
    return service_restarted


def request_attempts(url, params, max_retries=10, timeout=120.0):
    """
    Fetch responses from an API with attempts.

    Args:
        url (str): The initial URL to request.
        params (dict): Query parameters for the request.
        max_retries (int): Maximum number of retries for transient errors.
        timeout (float): Timeout for the HTTP request in seconds.

    Returns:
        tuple: A list of combined responses and the format header.
    """
    responses = []
    retries = 0

    while True:
        try:
            # Make the HTTP request
            response = httpx.get(url, params=params, timeout=timeout)

            if response.status_code == 472:
                break
            else:
                response.raise_for_status()  # Raise for HTTP errors

                # Parse and append the response
                data = response.json().get("response", [])
                break

        except httpx.RequestError as e:
            log.error(f"Request error: {e}")
            if retries < max_retries:
                retries += 1
                log.warning(f"Retrying... attempt {retries}")
            else:
                log.error("Max retries exceeded. Exiting pagination.")
                break
        except KeyError as e:
            log.error(f"Key error: {e}. Response format may have changed.")
            break
        except Exception as e:
            log.error(f"Unexpected error: {e}")
            break
    # Return responses and format header (if available)
    format_header = data.get("header", {}).get("format", None) if "data" in locals() else None
    return responses, format_header


def response_to_df(response, columns):
    rows = []
    for item in response:
        if "ticks" in item:
            ticks = item["ticks"][0]
        if "contract" in item:
            contract = item["contract"]
            row = {**contract, **dict(zip(columns, ticks))}
        else:
            row = dict(zip(columns, item))
        rows.append(row)
    df = pd.DataFrame(rows)
    rename_dict = {
        "strike": "strike_milli",
        "underlying_price": "underlying",
        "expiration": "exp",
        "root": "symbol",
    }
    for k, v in rename_dict.items():
        if k in df.columns:
            df.rename(columns={k: v}, inplace=True)
    return df


def multi_root_query_df(roots: list[str], params: dict, url: str):
    if not isinstance(roots, list):
        roots = [roots]
    responses_dfs = []
    for root in roots:
        params["root"] = root
        response, columns = request_attempts(url, params)
        df = response_to_df(response, columns)
        responses_dfs.append(df)
    return pd.concat(responses_dfs)


def multi_root_query_list(roots: list[str], params: dict, url: str):
    if not isinstance(roots, list):
        roots = [roots]
    responses_list = []
    for root in roots:
        params["root"] = root
        response, _ = request_attempts(url, params)
        responses_list.extend(response)
    return sorted(list(set(responses_list)))


# --------------------------------------------------------------
# Prepare inputs for the asyncio
# --------------------------------------------------------------


async def bulk_csv_request_async(session, url, params):
    """Async version with pagination support"""
    dfs = []

    while url is not None:
        async with session.get(url, params=params, timeout=aiohttp.ClientTimeout(total=60)) as response:
            response.raise_for_status()
            text = await response.text()

            # Parse CSV
            csv_reader = csv.reader(text.split("\n"))
            data = list(csv_reader)
            header = data[0]
            rows = [r for r in data[1:] if len(r) > 0]
            df = pd.DataFrame(rows, columns=header)
            dfs.append(df)

            # Handle pagination
            if "Next-Page" in response.headers and response.headers["Next-Page"] != "null":
                url = response.headers["Next-Page"]
                params = None
                print("Requesting Next Page,", url)
            else:
                url = None

    if len(dfs) > 0:
        return pd.concat(dfs).reset_index(drop=True)
    return pd.DataFrame()


async def get_bulk_quote_historical_async(session, params):
    url = os.getenv("BASE_URL") + "/bulk_snapshot/option/quote"
    df = await bulk_csv_request_async(session, url, params)
    df = df.drop(columns=["ms_of_day", "bid_condition", "bid_exchange", "ask_exchange", "ask_condition"])
    return "quotes", params["exp"], df


async def get_bulk_greeks_historical_async(session, params):
    url = os.getenv("BASE_URL") + "/bulk_snapshot/option/greeks"
    df = await bulk_csv_request_async(session, url, params)
    df = df.drop(columns=["ms_of_day2", "bid", "ask"])
    return "greeks", params["exp"], df


async def fetch_all_data(expirations, ticker):
    """Replace the joblib parallel processing"""
    params_base = {
        "root": ticker,
        "use_csv": "true",
    }

    # Create connector with connection pooling
    connector = aiohttp.TCPConnector(limit=100, limit_per_host=30)

    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = []

        for exp in expirations:
            params = params_base.copy()
            params["exp"] = exp

            # Add both greeks and quotes tasks
            tasks.append(get_bulk_greeks_historical_async(session, params))
            tasks.append(get_bulk_quote_historical_async(session, params))

        # Execute all tasks concurrently
        returns = await asyncio.gather(*tasks, return_exceptions=True)

        # Filter out any exceptions
        valid_returns = []
        for r in returns:
            if isinstance(r, Exception):
                log.error(f"Error fetching data: {r}")
            else:
                valid_returns.append(r)

        return valid_returns


async def fetch_quotes_greeks_all_exps(ticker):
    """Fetch all greeks and quotes data concurrently"""
    params = {
        "root": ticker,
        "use_csv": "true",
        "exp": "0",
    }

    # Create connector with connection pooling for better performance
    connector = aiohttp.TCPConnector(limit=100, limit_per_host=30)

    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = []

        tasks.append(get_bulk_greeks_historical_async(session, params))
        tasks.append(get_bulk_quote_historical_async(session, params))

        returns = await asyncio.gather(*tasks, return_exceptions=True)

        valid_returns = []
        for r in returns:
            if isinstance(r, Exception):
                log.error(f"Error fetching data: {r}")
            else:
                valid_returns.append(r)

        return valid_returns


if __name__ == "__main__":
    test_theta_data_connection()
