#!/usr/bin/env python3
"""
Theta Terminal v3 API Examples

This script demonstrates how to use the Theta Terminal v3 REST API
with various features like NDJSON format, CSV format, and pandas integration.

Requirements:
    pip install requests pandas

Usage:
    python examples.py

Note: This script uses v3 API endpoints. Please verify data endpoint paths
      from https://docs.thetadata.us/ as they may have changed from v2.
"""

import requests
import json
import pandas as pd
import io
from datetime import datetime, timedelta
from typing import Dict, List, Any


class ThetaTerminalV3:
    """Simple client for Theta Terminal v3 API"""

    def __init__(self, base_url: str = "http://localhost:25500"):
        self.base_url = base_url

    def get_mdds_status(self) -> str:
        """Check terminal MDDS connection status"""
        response = requests.get(f"{self.base_url}/v3/terminal/mdds/status")
        response.raise_for_status()
        return response.text

    def get_fpss_status(self) -> str:
        """Check terminal FPSS connection status"""
        response = requests.get(f"{self.base_url}/v3/terminal/fpss/status")
        response.raise_for_status()
        return response.text

    def get_version(self) -> Dict:
        """
        Get terminal version information

        Note: Endpoint path may have changed in v3. Check docs at:
        https://docs.thetadata.us/docs/rest-api/system-commands
        """
        # Try v3 path first, fall back to v2 if needed
        try:
            response = requests.get(f"{self.base_url}/v3/terminal/version")
            response.raise_for_status()
            return response.json()
        except:
            # Fallback to v2 endpoint if v3 doesn't exist
            response = requests.get(f"{self.base_url}/v2/system/version")
            response.raise_for_status()
            return response.json()

    def get_option_chain(self, root: str, exp: str = None, format: str = "json") -> Any:
        """
        Get option chain for a symbol

        Note: Verify endpoint path from v3 docs at https://docs.thetadata.us/
        This may still be /v2/snapshot/option/chain or changed to v3 path.

        Args:
            root: Stock symbol (e.g., 'SPY')
            exp: Expiration date (YYYY-MM-DD format), optional
            format: Response format ('json', 'ndjson', 'csv')

        Returns:
            Option chain data in requested format
        """
        # TODO: Verify correct v3 path from docs
        # Attempting v2 path (may work in v3 terminal)
        params = {"root": root, "format": format}
        if exp:
            params["exp"] = exp

        response = requests.get(f"{self.base_url}/v2/snapshot/option/chain", params=params)
        response.raise_for_status()

        if format == "json":
            return response.json()
        elif format == "ndjson":
            return [json.loads(line) for line in response.text.strip().split("\n") if line]
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text

    def get_historical_quotes(
        self,
        root: str,
        exp: str,
        strike: float,
        right: str,
        start_date: str,
        end_date: str,
        format: str = "json",
    ) -> Any:
        """
        Get historical option quotes (v3 unified endpoint - no pagination!)

        Note: Verify endpoint path from v3 docs at https://docs.thetadata.us/

        Args:
            root: Stock symbol (e.g., 'SPY')
            exp: Expiration date (YYYY-MM-DD)
            strike: Strike price
            right: 'C' for call, 'P' for put
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            format: Response format ('json', 'ndjson', 'csv')

        Returns:
            Historical quotes in requested format (NO PAGINATION in v3!)
        """
        params = {
            "root": root,
            "exp": exp,
            "strike": strike,
            "right": right,
            "start_date": start_date,
            "end_date": end_date,
            "format": format,
        }

        # TODO: Verify correct v3 path from docs
        response = requests.get(f"{self.base_url}/v2/hist/option/quote", params=params)
        response.raise_for_status()

        if format == "json":
            return response.json()
        elif format == "ndjson":
            return [json.loads(line) for line in response.text.strip().split("\n") if line]
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text

    def get_historical_trades(
        self,
        root: str,
        exp: str,
        strike: float,
        right: str,
        start_date: str,
        end_date: str,
        format: str = "ndjson",
    ) -> Any:
        """
        Get historical option trades
        NDJSON format recommended for large datasets

        Note: Verify endpoint path from v3 docs at https://docs.thetadata.us/
        """
        params = {
            "root": root,
            "exp": exp,
            "strike": strike,
            "right": right,
            "start_date": start_date,
            "end_date": end_date,
            "format": format,
        }

        # TODO: Verify correct v3 path from docs
        response = requests.get(f"{self.base_url}/v2/hist/option/trade", params=params)
        response.raise_for_status()

        if format == "ndjson":
            # NDJSON is perfect for streaming large datasets
            return [json.loads(line) for line in response.text.strip().split("\n") if line]
        elif format == "json":
            return response.json()
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text


def example_1_check_connection():
    """Example 1: Check if terminal is connected"""
    print("Example 1: Checking terminal connection...")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        mdds_status = client.get_mdds_status()
        print(f"✓ MDDS Status: {mdds_status}")

        fpss_status = client.get_fpss_status()
        print(f"✓ FPSS Status: {fpss_status}")

        try:
            version = client.get_version()
            print(f"✓ Terminal Version: {version}")
        except:
            print("⚠ Could not get version (endpoint may have changed)")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Make sure the terminal is running: 'make up'")

    print()


def example_2_option_chain_json():
    """Example 2: Get option chain in JSON format"""
    print("Example 2: Get SPY option chain (JSON)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # Get next Friday's expiration
        today = datetime.now()
        days_ahead = 4 - today.weekday()  # Friday = 4
        if days_ahead <= 0:
            days_ahead += 7
        next_friday = today + timedelta(days=days_ahead)
        exp_date = next_friday.strftime("%Y-%m-%d")

        print(f"Fetching SPY options expiring {exp_date}...")

        chain = client.get_option_chain("SPY", exp=exp_date, format="json")

        print(f"✓ Retrieved {len(chain)} contracts")
        if chain:
            print(f"✓ Sample contract keys: {list(chain[0].keys()) if isinstance(chain[0], dict) else 'N/A'}")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Note: Verify API endpoint path from https://docs.thetadata.us/")

    print()


def example_3_option_chain_pandas():
    """Example 3: Get option chain directly into pandas DataFrame"""
    print("Example 3: Get SPY option chain (pandas DataFrame)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # CSV format works great with pandas
        df = client.get_option_chain("SPY", format="csv")

        print(f"✓ Retrieved {len(df)} contracts")
        print(f"\nDataFrame columns: {list(df.columns)}")

        print(f"\nFirst 5 contracts:")
        print(df.head())

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Note: Verify API endpoint path from https://docs.thetadata.us/")

    print()


def example_4_historical_data_ndjson():
    """Example 4: Get historical data with NDJSON (best for large datasets)"""
    print("Example 4: Historical option quotes (NDJSON format)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")

        # Use a recent expiration that's likely valid
        exp_date = (datetime.now() + timedelta(days=14)).strftime("%Y-%m-%d")

        print(f"Fetching SPY quotes from {start_date} to {end_date}...")
        print("Using NDJSON format (recommended for large datasets)...")

        # NDJSON is best for large datasets - efficient parsing
        quotes = client.get_historical_quotes(
            root="SPY",
            exp=exp_date,
            strike=450,
            right="C",
            start_date=start_date,
            end_date=end_date,
            format="ndjson",
        )

        print(f"✓ Retrieved {len(quotes)} quotes")
        if quotes:
            print(f"✓ First quote keys: {list(quotes[0].keys()) if isinstance(quotes[0], dict) else 'N/A'}")

        # Convert to pandas if needed
        if quotes:
            df = pd.DataFrame(quotes)
            print(f"\n✓ DataFrame shape: {df.shape}")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Note: Verify API endpoint path and parameters from https://docs.thetadata.us/")

    print()


def example_5_no_pagination():
    """Example 5: Demonstrate no pagination needed (v3 feature!)"""
    print("Example 5: Large dataset - NO PAGINATION NEEDED! 🎉")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # Get a month of data in ONE request
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
        exp_date = (datetime.now() + timedelta(days=14)).strftime("%Y-%m-%d")

        print(f"Fetching 30 days of data ({start_date} to {end_date})...")
        print("In v2, this might require multiple requests with pagination.")
        print("In v3, it's just ONE request! ✓")

        quotes = client.get_historical_quotes(
            root="SPY",
            exp=exp_date,
            strike=450,
            right="C",
            start_date=start_date,
            end_date=end_date,
            format="ndjson",  # NDJSON handles large responses efficiently
        )

        print(f"✓ Retrieved {len(quotes)} quotes in a single request!")
        print(f"✓ No pagination handling needed")
        print(f"✓ No multiple network requests")
        print(f"✓ Much simpler code")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Note: Adjust expiration date or check API docs")

    print()


def example_6_concurrent_requests():
    """Example 6: Multiple concurrent requests (v3 supports more!)"""
    print("Example 6: Concurrent requests (v3 allows 2x more!)")
    print("-" * 50)

    from concurrent.futures import ThreadPoolExecutor, as_completed

    client = ThetaTerminalV3()

    # Multiple symbols to fetch
    symbols = ["SPY", "QQQ", "IWM", "DIA", "AAPL"]

    def fetch_chain(symbol):
        """Fetch option chain for a symbol"""
        try:
            chain = client.get_option_chain(symbol, format="json")
            return symbol, len(chain) if chain else 0, None
        except Exception as e:
            return symbol, 0, str(e)

    print(f"Fetching option chains for {len(symbols)} symbols concurrently...")

    # v3 supports more concurrent requests than v2
    max_workers = 10  # Up from 5 in v2!

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_chain, sym): sym for sym in symbols}

        results = []
        for future in as_completed(futures):
            symbol, count, error = future.result()
            if error:
                print(f"✗ {symbol}: {error}")
            else:
                print(f"✓ {symbol}: {count} contracts")
            results.append((symbol, count, error))

    successful = sum(1 for _, _, e in results if e is None)
    print(f"\n✓ Successfully fetched {successful}/{len(symbols)} symbols")

    print()


if __name__ == "__main__":
    print("=" * 50)
    print("Theta Terminal v3 API Examples")
    print("=" * 50)
    print()

    print("⚠ IMPORTANT: Some endpoint paths may have changed in v3.")
    print("   Please verify from: https://docs.thetadata.us/")
    print()

    # Run all examples
    example_1_check_connection()
    example_2_option_chain_json()
    example_3_option_chain_pandas()
    example_4_historical_data_ndjson()
    example_5_no_pagination()
    example_6_concurrent_requests()

    print("=" * 50)
    print("Examples complete!")
    print("=" * 50)
    print()
    print("Key v3 features demonstrated:")
    print("✓ No pagination - single requests only")
    print("✓ Multiple output formats (JSON, NDJSON, CSV)")
    print("✓ Direct pandas integration")
    print("✓ Better concurrent request support")
    print("✓ Simpler, cleaner code")
    print()
    print("Documentation: https://docs.thetadata.us/")
    print()
    print("Note: Data API endpoint paths (/v2/* or /v3/*) should be")
    print("      verified from the official documentation above.")

    def get_option_chain(self, root: str, exp: str = None, format: str = "json") -> Any:
        """
        Get option chain for a symbol

        Args:
            root: Stock symbol (e.g., 'SPY')
            exp: Expiration date (YYYY-MM-DD format), optional
            format: Response format ('json', 'ndjson', 'csv')

        Returns:
            Option chain data in requested format
        """
        params = {"root": root, "format": format}
        if exp:
            params["exp"] = exp

        response = requests.get(f"{self.base_url}/v2/snapshot/option/chain", params=params)
        response.raise_for_status()

        if format == "json":
            return response.json()
        elif format == "ndjson":
            return [json.loads(line) for line in response.text.strip().split("\n")]
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text

    def get_historical_quotes(
        self,
        root: str,
        exp: str,
        strike: float,
        right: str,
        start_date: str,
        end_date: str,
        format: str = "json",
    ) -> Any:
        """
        Get historical option quotes (v3 unified endpoint - no pagination!)

        Args:
            root: Stock symbol (e.g., 'SPY')
            exp: Expiration date (YYYY-MM-DD)
            strike: Strike price
            right: 'C' for call, 'P' for put
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            format: Response format ('json', 'ndjson', 'csv')

        Returns:
            Historical quotes in requested format
        """
        params = {
            "root": root,
            "exp": exp,
            "strike": strike,
            "right": right,
            "start_date": start_date,
            "end_date": end_date,
            "format": format,
        }

        response = requests.get(f"{self.base_url}/v2/hist/option/quote", params=params)
        response.raise_for_status()

        if format == "json":
            return response.json()
        elif format == "ndjson":
            return [json.loads(line) for line in response.text.strip().split("\n")]
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text

    def get_historical_trades(
        self,
        root: str,
        exp: str,
        strike: float,
        right: str,
        start_date: str,
        end_date: str,
        format: str = "ndjson",
    ) -> Any:
        """
        Get historical option trades
        NDJSON format recommended for large datasets
        """
        params = {
            "root": root,
            "exp": exp,
            "strike": strike,
            "right": right,
            "start_date": start_date,
            "end_date": end_date,
            "format": format,
        }

        response = requests.get(f"{self.base_url}/v2/hist/option/trade", params=params)
        response.raise_for_status()

        if format == "ndjson":
            # NDJSON is perfect for streaming large datasets
            return [json.loads(line) for line in response.text.strip().split("\n") if line]
        elif format == "json":
            return response.json()
        elif format == "csv":
            return pd.read_csv(io.StringIO(response.text))

        return response.text


def example_1_check_connection():
    """Example 1: Check if terminal is connected"""
    print("Example 1: Checking terminal connection...")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        status = client.get_status()
        print(f"✓ Terminal Status: {status}")

        version = client.get_version()
        print(f"✓ Terminal Version: {version}")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Make sure the terminal is running: 'make up'")

    print()


def example_2_option_chain_json():
    """Example 2: Get option chain in JSON format"""
    print("Example 2: Get SPY option chain (JSON)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # Get next Friday's expiration
        today = datetime.now()
        days_ahead = 4 - today.weekday()  # Friday = 4
        if days_ahead <= 0:
            days_ahead += 7
        next_friday = today + timedelta(days=days_ahead)
        exp_date = next_friday.strftime("%Y-%m-%d")

        print(f"Fetching SPY options expiring {exp_date}...")

        chain = client.get_option_chain("SPY", exp=exp_date, format="json")

        print(f"✓ Retrieved {len(chain)} contracts")
        if chain:
            print(f"✓ Sample contract: {chain[0]}")

    except Exception as e:
        print(f"✗ Error: {e}")

    print()


def example_3_option_chain_pandas():
    """Example 3: Get option chain directly into pandas DataFrame"""
    print("Example 3: Get SPY option chain (pandas DataFrame)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # CSV format works great with pandas
        df = client.get_option_chain("SPY", format="csv")

        print(f"✓ Retrieved {len(df)} contracts")
        print(f"\nDataFrame Info:")
        print(df.info())

        print(f"\nFirst 5 contracts:")
        print(df.head())

    except Exception as e:
        print(f"✗ Error: {e}")

    print()


def example_4_historical_data_ndjson():
    """Example 4: Get historical data with NDJSON (best for large datasets)"""
    print("Example 4: Historical option quotes (NDJSON format)")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")

        print(f"Fetching SPY quotes from {start_date} to {end_date}...")
        print("Using NDJSON format (recommended for large datasets)...")

        # NDJSON is best for large datasets - efficient parsing
        quotes = client.get_historical_quotes(
            root="SPY",
            exp="2024-12-20",  # Adjust to valid expiration
            strike=450,
            right="C",
            start_date=start_date,
            end_date=end_date,
            format="ndjson",
        )

        print(f"✓ Retrieved {len(quotes)} quotes")
        if quotes:
            print(f"✓ First quote: {quotes[0]}")
            print(f"✓ Last quote: {quotes[-1]}")

        # Convert to pandas if needed
        df = pd.DataFrame(quotes)
        print(f"\n✓ DataFrame shape: {df.shape}")

    except Exception as e:
        print(f"✗ Error: {e}")

    print()


def example_5_no_pagination():
    """Example 5: Demonstrate no pagination needed (v3 feature!)"""
    print("Example 5: Large dataset - NO PAGINATION NEEDED! 🎉")
    print("-" * 50)

    client = ThetaTerminalV3()

    try:
        # Get a full year of data in ONE request
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=365)).strftime("%Y-%m-%d")

        print(f"Fetching 1 year of data ({start_date} to {end_date})...")
        print("In v2, this would require multiple requests with pagination.")
        print("In v3, it's just ONE request! ✓")

        quotes = client.get_historical_quotes(
            root="SPY",
            exp="2024-12-20",  # Adjust to valid expiration
            strike=450,
            right="C",
            start_date=start_date,
            end_date=end_date,
            format="ndjson",  # NDJSON handles large responses efficiently
        )

        print(f"✓ Retrieved {len(quotes)} quotes in a single request!")
        print(f"✓ No pagination handling needed")
        print(f"✓ No multiple network requests")
        print(f"✓ Much simpler code")

    except Exception as e:
        print(f"✗ Error: {e}")
        print("Note: Make sure the expiration date is valid")

    print()


def example_6_concurrent_requests():
    """Example 6: Multiple concurrent requests (v3 supports more!)"""
    print("Example 6: Concurrent requests (v3 allows 2x more!)")
    print("-" * 50)

    from concurrent.futures import ThreadPoolExecutor, as_completed

    client = ThetaTerminalV3()

    # Multiple symbols to fetch
    symbols = ["SPY", "QQQ", "IWM", "DIA", "AAPL"]

    def fetch_chain(symbol):
        """Fetch option chain for a symbol"""
        try:
            chain = client.get_option_chain(symbol, format="json")
            return symbol, len(chain), None
        except Exception as e:
            return symbol, 0, str(e)

    print(f"Fetching option chains for {len(symbols)} symbols concurrently...")

    # v3 supports more concurrent requests than v2
    max_workers = 10  # Up from 5 in v2!

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_chain, sym): sym for sym in symbols}

        results = []
        for future in as_completed(futures):
            symbol, count, error = future.result()
            if error:
                print(f"✗ {symbol}: {error}")
            else:
                print(f"✓ {symbol}: {count} contracts")
            results.append((symbol, count, error))

    successful = sum(1 for _, _, e in results if e is None)
    print(f"\n✓ Successfully fetched {successful}/{len(symbols)} symbols")

    print()


if __name__ == "__main__":
    print("=" * 50)
    print("Theta Terminal v3 API Examples")
    print("=" * 50)
    print()

    # Run all examples
    example_1_check_connection()
    example_2_option_chain_json()
    example_3_option_chain_pandas()
    example_4_historical_data_ndjson()
    example_5_no_pagination()
    example_6_concurrent_requests()

    print("=" * 50)
    print("Examples complete!")
    print("=" * 50)
    print()
    print("Key v3 features demonstrated:")
    print("✓ No pagination - single requests only")
    print("✓ Multiple output formats (JSON, NDJSON, CSV)")
    print("✓ Direct pandas integration")
    print("✓ Better concurrent request support")
    print("✓ Simpler, cleaner code")
    print()
    print("For more examples, see: https://docs.thetadata.us/")
