#!/usr/bin/env python3
"""
Theta Terminal v3 - Connection & Endpoint Test Suite

Tests all major v3 API endpoints to verify connectivity and functionality.
Based on the official OpenAPI v3 specification.

Usage:
    python test_v3_endpoints.py
"""

import requests
import json
from datetime import datetime, timedelta
from typing import Dict, Tuple, Optional
import sys


class ThetaV3Tester:
    """Comprehensive tester for Theta Terminal v3 API"""

    def __init__(self, base_url: str = "http://127.0.0.1:25500"):
        self.base_url = base_url
        self.results = {"passed": [], "failed": [], "skipped": []}

    def test_endpoint(
        self, name: str, path: str, params: Optional[Dict] = None, method: str = "GET"
    ) -> Tuple[bool, str, Optional[any]]:
        """
        Test a single endpoint

        Returns:
            (success, message, data)
        """
        url = f"{self.base_url}{path}"

        try:
            if method == "GET":
                response = requests.get(url, params=params, timeout=10)
            else:
                response = requests.head(url, params=params, timeout=10)

            # Success codes
            if 200 <= response.status_code < 300:
                return True, f"✓ {response.status_code}", response

            # Client errors
            elif 400 <= response.status_code < 500:
                if response.status_code == 410:
                    return False, "✗ 410 Gone (v2 endpoint)", None
                elif response.status_code == 404:
                    return False, "✗ 404 Not Found", None
                elif response.status_code == 422:
                    return False, "⚠ 422 Unprocessable (params issue)", None
                else:
                    return False, f"✗ {response.status_code} Error", None

            # Server errors
            else:
                return False, f"✗ {response.status_code} Server Error", None

        except requests.exceptions.Timeout:
            return False, "✗ Timeout", None
        except requests.exceptions.ConnectionError:
            return False, "✗ Connection Error", None
        except Exception as e:
            return False, f"✗ {str(e)[:50]}", None

    def run_test(self, category: str, name: str, path: str, params: Optional[Dict] = None):
        """Run a test and record results"""
        success, message, data = self.test_endpoint(name, path, params)

        result = {
            "category": category,
            "name": name,
            "path": path,
            "message": message,
            "data_size": len(data.text) if data else 0,
        }

        if success:
            self.results["passed"].append(result)
            print(f"  {message:25} {name}")
            if data and len(data.text) < 200:
                print(f"    Response: {data.text[:100]}")
        else:
            self.results["failed"].append(result)
            print(f"  {message:25} {name}")

    def print_section(self, title: str):
        """Print a section header"""
        print(f"\n{'=' * 70}")
        print(f"{title}")
        print(f"{'=' * 70}")

    def test_terminal_status(self):
        """Test terminal status endpoints"""
        self.print_section("Terminal Status & Control")

        tests = [
            ("MDDS Status", "/v3/terminal/mdds/status", None),
            ("FPSS Status", "/v3/terminal/fpss/status", None),
        ]

        for name, path, params in tests:
            self.run_test("Terminal", name, path, params)

    def test_stock_list_endpoints(self):
        """Test stock list endpoints"""
        self.print_section("Stock - List Endpoints")

        tests = [
            ("List Symbols", "/v3/stock/list/symbols", {"format": "json"}),
            ("List Dates (Quote)", "/v3/stock/list/dates/quote", {"symbol": "AAPL", "format": "json"}),
            ("List Dates (Trade)", "/v3/stock/list/dates/trade", {"symbol": "SPY", "format": "json"}),
        ]

        for name, path, params in tests:
            self.run_test("Stock List", name, path, params)

    def test_stock_snapshot_endpoints(self):
        """Test stock snapshot endpoints"""
        self.print_section("Stock - Snapshot Endpoints")

        tests = [
            ("OHLC", "/v3/stock/snapshot/ohlc", {"symbol": "AAPL", "format": "json"}),
            ("Trade", "/v3/stock/snapshot/trade", {"symbol": "AAPL", "format": "json"}),
            ("Quote", "/v3/stock/snapshot/quote", {"symbol": "AAPL", "format": "json"}),
        ]

        for name, path, params in tests:
            self.run_test("Stock Snapshot", name, path, params)

    def test_stock_history_endpoints(self):
        """Test stock historical endpoints"""
        self.print_section("Stock - Historical Endpoints")

        # Get dates
        today = datetime.now()
        yesterday = today - timedelta(days=1)
        week_ago = today - timedelta(days=7)

        # Format dates
        today_str = today.strftime("%Y-%m-%d")
        yesterday_str = yesterday.strftime("%Y-%m-%d")
        week_ago_str = week_ago.strftime("%Y-%m-%d")

        tests = [
            (
                "Quote History",
                "/v3/stock/history/quote",
                {"symbol": "AAPL", "start_date": week_ago_str, "end_date": yesterday_str, "format": "json"},
            ),
            (
                "Trade History",
                "/v3/stock/history/trade",
                {"symbol": "SPY", "start_date": week_ago_str, "end_date": yesterday_str, "format": "json"},
            ),
        ]

        for name, path, params in tests:
            self.run_test("Stock History", name, path, params)

    def test_option_list_endpoints(self):
        """Test option list endpoints"""
        self.print_section("Option - List Endpoints")

        tests = [
            ("List Expirations", "/v3/option/list/expirations", {"symbol": "SPY", "format": "json"}),
            (
                "List Strikes",
                "/v3/option/list/strikes",
                {"symbol": "SPY", "expiration": "2025-12-19", "format": "json"},
            ),
        ]

        for name, path, params in tests:
            self.run_test("Option List", name, path, params)

    def test_option_snapshot_endpoints(self):
        """Test option snapshot endpoints"""
        self.print_section("Option - Snapshot Endpoints")

        # Get next Friday for expiration
        today = datetime.now()
        days_ahead = 4 - today.weekday()
        if days_ahead <= 0:
            days_ahead += 7
        next_friday = today + timedelta(days=days_ahead)
        exp_date = next_friday.strftime("%Y-%m-%d")

        tests = [
            (
                "Option Quote",
                "/v3/option/snapshot/quote",
                {"symbol": "SPY", "expiration": exp_date, "strike": "600", "right": "call", "format": "json"},
            ),
            (
                "Option Trade",
                "/v3/option/snapshot/trade",
                {"symbol": "SPY", "expiration": exp_date, "strike": "600", "right": "call", "format": "json"},
            ),
            (
                "Option OHLC",
                "/v3/option/snapshot/ohlc",
                {"symbol": "SPY", "expiration": exp_date, "strike": "600", "right": "call", "format": "json"},
            ),
        ]

        for name, path, params in tests:
            self.run_test("Option Snapshot", name, path, params)

    def test_option_history_endpoints(self):
        """Test option historical endpoints"""
        self.print_section("Option - Historical Endpoints")

        today = datetime.now()
        week_ago = today - timedelta(days=7)

        today_str = today.strftime("%Y-%m-%d")
        week_ago_str = week_ago.strftime("%Y-%m-%d")

        # Use a recent expiration
        exp_date = (today + timedelta(days=14)).strftime("%Y-%m-%d")

        tests = [
            (
                "Option Quote History",
                "/v3/option/history/quote",
                {
                    "symbol": "SPY",
                    "expiration": exp_date,
                    "strike": "600",
                    "right": "call",
                    "start_date": week_ago_str,
                    "end_date": today_str,
                    "format": "json",
                },
            ),
            (
                "Option Trade History",
                "/v3/option/history/trade",
                {
                    "symbol": "SPY",
                    "expiration": exp_date,
                    "strike": "600",
                    "right": "call",
                    "start_date": week_ago_str,
                    "end_date": today_str,
                    "format": "json",
                },
            ),
        ]

        for name, path, params in tests:
            self.run_test("Option History", name, path, params)

    def test_format_support(self):
        """Test different output formats"""
        self.print_section("Format Support (JSON, NDJSON, CSV)")

        tests = [
            ("JSON Format", "/v3/stock/list/symbols", {"format": "json"}),
            ("NDJSON Format", "/v3/stock/list/symbols", {"format": "ndjson"}),
            ("CSV Format", "/v3/stock/list/symbols", {"format": "csv"}),
        ]

        for name, path, params in tests:
            self.run_test("Formats", name, path, params)

    def print_summary(self):
        """Print test summary"""
        self.print_section("Test Summary")

        total = len(self.results["passed"]) + len(self.results["failed"])
        passed = len(self.results["passed"])
        failed = len(self.results["failed"])

        print(f"\nTotal Tests: {total}")
        print(f"✓ Passed:    {passed} ({passed / total * 100:.1f}%)")
        print(f"✗ Failed:    {failed} ({failed / total * 100:.1f}%)")

        if self.results["failed"]:
            print(f"\n{'=' * 70}")
            print("Failed Tests:")
            print(f"{'=' * 70}")
            for result in self.results["failed"]:
                print(f"  {result['name']}")
                print(f"    Path: {result['path']}")
                print(f"    Status: {result['message']}")

        print(f"\n{'=' * 70}")
        print("Connectivity Status:")
        print(f"{'=' * 70}")

        # Check terminal connection
        terminal_tests = [r for r in self.results["passed"] if r["category"] == "Terminal"]
        if terminal_tests:
            print("✓ Terminal is CONNECTED and working")
            print("✓ MDDS and FPSS connections active")
        else:
            print("✗ Terminal connection issues detected")

        # Check data API
        data_tests = [r for r in self.results["passed"] if r["category"] != "Terminal"]
        if data_tests:
            print(f"✓ Data API is working ({len(data_tests)} endpoints tested)")
        else:
            print("⚠ No data API endpoints tested successfully")

        print()

    def run_all_tests(self):
        """Run all test suites"""
        print("=" * 70)
        print("Theta Terminal v3 - API Endpoint Test Suite")
        print("=" * 70)
        print(f"Testing: {self.base_url}")
        print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # Run all test suites
        self.test_terminal_status()
        self.test_stock_list_endpoints()
        self.test_stock_snapshot_endpoints()
        self.test_stock_history_endpoints()
        self.test_option_list_endpoints()
        self.test_option_snapshot_endpoints()
        self.test_option_history_endpoints()
        self.test_format_support()

        # Print summary
        self.print_summary()

        # Return exit code
        return 0 if len(self.results["failed"]) == 0 else 1


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="Test Theta Terminal v3 API endpoints")
    parser.add_argument(
        "--url",
        default="http://localhost:25500",
        help="Base URL of the terminal (default: http://localhost:25500)",
    )

    args = parser.parse_args()

    tester = ThetaV3Tester(base_url=args.url)
    exit_code = tester.run_all_tests()

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
