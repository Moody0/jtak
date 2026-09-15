#!/usr/bin/env python3
"""Replace one merchant catalog from the JTAK Market workbook.

The script creates new Product records for every workbook row, so no ProductId
is reused between merchants. It replaces only the selected merchant's
MerchantProduct links after all products have been created and verified.

Dry-run is the default. Use --apply only after reviewing the summary.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import openpyxl

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


API = os.environ.get("JTAK_API", "https://api.jtak.app")


def request(method: str, path: str, token: str | None = None, payload=None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {"Accept": "application/json", "User-Agent": "JTAK-Catalog-Importer/1.0", "Host": urllib.parse.urlparse(API).hostname or "api.jtak.app"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=body, headers=headers, method=method)
    context = ssl.create_default_context()
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, context=context, timeout=90) as response:
                raw = response.read().decode("utf-8")
                try:
                    value = json.loads(raw) if raw else None
                except json.JSONDecodeError:
                    value = raw
                return response.status, value
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            if exc.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"{method} {path} -> HTTP {exc.code}: {raw[:500]}") from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"{method} {path} failed: {exc}") from exc


def token_from_env() -> str:
    username = os.environ.get("JTAK_ADMIN_USERNAME")
    password = os.environ.get("JTAK_ADMIN_PASSWORD")
    if not username or not password:
        raise RuntimeError("Set JTAK_ADMIN_USERNAME and JTAK_ADMIN_PASSWORD before --apply")
    form = urllib.parse.urlencode({
        "grant_type": "password",
        "username": username,
        "password": password,
        "scope": "offline_access profile roles phone email",
    }).encode("utf-8")
    req = urllib.request.Request(
        API + "/connect/token",
        data=form,
        headers={"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json", "User-Agent": "JTAK-Catalog-Importer/1.0", "Host": urllib.parse.urlparse(API).hostname or "api.jtak.app"},
        method="POST",
    )
    with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=60) as response:
        value = json.loads(response.read().decode("utf-8"))
    if not value.get("access_token"):
        raise RuntimeError("Authentication response did not contain an access token")
    return value["access_token"]


def price_value(value, row: int) -> float:
    # Excel can interpret an entry such as 1.18 as a date. Recover its intended
    # decimal representation from the month/day rather than importing a date.
    if isinstance(value, (dt.datetime, dt.date)):
        value = value.month + value.day / 100
    if isinstance(value, str):
        value = value.strip().replace(",", "")
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"row {row}: invalid السعر value {value!r}") from exc
    if result < 0:
        raise ValueError(f"row {row}: السعر cannot be negative")
    return result


def text(value) -> str:
    return "" if value is None else str(value).strip()


def read_rows(path: Path):
    sheet = openpyxl.load_workbook(path, read_only=False, data_only=True).active
    headers = [cell.value for cell in sheet[1]]
    index = {str(value).strip(): i for i, value in enumerate(headers) if value is not None}
    required = ["اسم المنتج بالعربي", "اسم المنتج بالإنجليزي", "باركود", "السعر"]
    missing = [name for name in required if name not in index]
    if missing:
        raise RuntimeError(f"Workbook is missing required columns: {', '.join(missing)}")

    rows = []
    barcode_counts = {}
    for row_number, values in enumerate(sheet.iter_rows(min_row=2, values_only=True), 2):
        title = text(values[index["اسم المنتج بالعربي"]])
        barcode_raw = values[index["باركود"]]
        if not title and barcode_raw is None:
            continue
        if not title or barcode_raw is None:
            raise ValueError(f"row {row_number}: title and barcode are required")
        if len(title) > 256:
            raise ValueError(f"row {row_number}: Arabic title is longer than the supported 256 characters")
        barcode = text(barcode_raw)
        if barcode.endswith(".0"):
            barcode = barcode[:-2]
        item = {
            "row": row_number,
            "title": title,
            "titleEn": text(values[index["اسم المنتج بالإنجليزي"]]) or title,
            "barcode": barcode,
            "brand": text(values[index.get("اسم الماركة", -1)]) if "اسم الماركة" in index else "",
            "description": text(values[index.get("وصف المنتج بالعربي", -1)]) if "وصف المنتج بالعربي" in index else title,
            "descriptionEn": text(values[index.get("وصف المنتج بالإنجليزي", -1)]) if "وصف المنتج بالإنجليزي" in index else "",
            "unit": text(values[index.get("الوحدة", -1)]) if "الوحدة" in index else "قطعة",
            "photo": text(values[index.get("رابط صورة المنتج", -1)]) if "رابط صورة المنتج" in index else "",
            "mainCategory": text(values[index.get("القسم الرئيسي", -1)]) if "القسم الرئيسي" in index else "عام",
            "subCategory": text(values[index.get("القسم الفرعي", -1)]) if "القسم الفرعي" in index else "",
            "price": price_value(values[index["السعر"]], row_number),
        }
        item["description"] = item["description"] or title
        item["descriptionEn"] = item["descriptionEn"] or item["titleEn"]
        item["unit"] = item["unit"] or "قطعة"
        rows.append(item)
        barcode_counts[barcode] = barcode_counts.get(barcode, 0) + 1
    duplicates = {k: v for k, v in barcode_counts.items() if v > 1}
    return rows, duplicates


def category_id(main: str, sub: str, mains: dict, subs: dict):
    main = main or "عام"
    sub = sub or ""
    mid = mains.get(main)
    if mid is None:
        return None
    return subs.get((mid, sub), mid)


def sync_categories(rows, token):
    status, result = request("POST", "/api/v1/Admin/ProductCategories/DataTable", token, {
        "pageNumber": 0, "pageSize": 10000, "sortField": "id", "sortOrder": "asc"
    })
    if status != 200:
        raise RuntimeError(f"category list failed with HTTP {status}")
    items = result.get("items", [])
    mains = {text(x.get("title")): x["id"] for x in items if not x.get("parentId")}
    subs = {(x.get("parentId"), text(x.get("title"))): x["id"] for x in items if x.get("parentId")}
    pairs = sorted({(x["mainCategory"] or "عام", x["subCategory"]) for x in rows})
    for main, sub in pairs:
        if main not in mains:
            _, created = request("POST", "/api/v1/Admin/ProductCategories", token, {"title": main, "parentId": None, "active": True})
            mains[main] = int(created)
        if sub and (mains[main], sub) not in subs:
            _, created = request("POST", "/api/v1/Admin/ProductCategories", token, {"title": sub, "parentId": mains[main], "active": True})
            subs[(mains[main], sub)] = int(created)
    return mains, subs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workbook", type=Path, default=Path(r"C:\Users\HP\Downloads\جيتك.xlsx"))
    parser.add_argument("--merchant-id", type=int, default=12)
    parser.add_argument("--backup", type=Path, default=Path("artifacts/jtak-market-products-backup.json"))
    parser.add_argument("--apply", action="store_true", help="create products and replace merchant assignments")
    args = parser.parse_args()

    rows, duplicates = read_rows(args.workbook)
    print(f"Workbook: {args.workbook}")
    print(f"Rows: {len(rows)}; duplicate barcode groups: {len(duplicates)}; duplicate rows: {sum(v - 1 for v in duplicates.values())}")
    print("Price source: السعر only; السعر قبل الخصم is not imported")
    print("Product ownership: every row creates a new Product record; no existing ProductId is reused")
    if duplicates:
        print("Warning: duplicate barcodes are preserved as separate workbook rows")
    if not args.apply:
        print("Dry run only. Re-run with --apply and credentials in JTAK_ADMIN_USERNAME/JTAK_ADMIN_PASSWORD to mutate the catalog.")
        return 0

    token = token_from_env()
    # Refuse to start a destructive import against the old deployment. The
    # current catalog API must expose the barcode field added for this import;
    # otherwise long workbook titles and barcodes would be silently truncated
    # or rejected after partial creation.
    probe_status, probe = request("POST", "/api/v1/Admin/Products/DataTable", token, {
        "pageNumber": 0, "pageSize": 1, "sortField": "id", "sortOrder": "desc"
    })
    if probe_status != 200 or not isinstance(probe, dict) or not probe.get("items") or "barcode" not in probe["items"][0]:
        raise RuntimeError("backend is not ready: deploy the Product.Barcode schema/API changes before --apply")
    status, current = request("GET", f"/api/v1/Admin/Merchants/Products/{args.merchant_id}", token)
    if status != 200 or not isinstance(current, list):
        raise RuntimeError("could not read current merchant catalog")
    args.backup.parent.mkdir(parents=True, exist_ok=True)
    args.backup.write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved rollback snapshot: {args.backup} ({len(current)} existing assignments)")

    mains, subs = sync_categories(rows, token)
    payloads = []
    for index, item in enumerate(rows):
        payloads.append({
            "title": item["title"], "titleEn": item["titleEn"], "barcode": item["barcode"], "brand": item["brand"],
            "description": item["description"], "descriptionEn": item["descriptionEn"],
            "unit": item["unit"], "photos": item["photo"],
            "productCategoryId": category_id(item["mainCategory"], item["subCategory"], mains, subs),
            "active": True, "isFeatured": True, "_row": item["row"], "_index": index,
        })

    def create(payload):
        row_number = payload.get("_row", "?")
        index = payload["_index"]
        body = {key: value for key, value in payload.items() if not key.startswith("_")}
        status, result = request("POST", "/api/v1/Admin/Products", token, body)
        if status != 200:
            raise RuntimeError(f"row {row_number}: product create failed with HTTP {status}")
        pid = int(result)
        if pid <= 0:
            raise RuntimeError(f"product create returned invalid id {result!r}")
        return index, pid

    # Futures complete out of order. Keep each returned ProductId at the same
    # index as its workbook row so merchant prices cannot be crossed between
    # products.
    product_ids = [0] * len(payloads)
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            for start in range(0, len(payloads), 8):
                futures = [pool.submit(create, payload) for payload in payloads[start:start + 8]]
                failures = []
                for future in concurrent.futures.as_completed(futures):
                    try:
                        index, product_id = future.result()
                        product_ids[index] = product_id
                    except Exception as exc:
                        failures.append(exc)
                if failures:
                    raise failures[0]
                created_count = sum(product_id > 0 for product_id in product_ids)
                if created_count % 100 < 8 or created_count == len(payloads):
                    print(f"Created {created_count}/{len(payloads)} products")
    except Exception:
        # A failed import must not leave a partial catalog of unassigned rows.
        # These IDs are known to have been created by this run and are safe to
        # soft-delete before re-raising the original error.
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda pid: request("DELETE", f"/api/v1/Admin/Products/{pid}", token)[0], product_ids))
        raise

    assignments = [{"productId": pid, "merchantPrice": item["price"], "profitOutOfMerchantPricePercent": 0, "additionalProfitPercent": 0, "discount": 0} for pid, item in zip(product_ids, rows)]
    status, result = request("PUT", f"/api/v1/Admin/Merchants/Products/{args.merchant_id}", token, assignments)
    if status != 200:
        raise RuntimeError(f"merchant replacement failed with HTTP {status}: {result}")
    status, verify = request("GET", f"/api/v1/Admin/Merchants/Products/{args.merchant_id}", token)
    assigned_ids = {x.get("productId") for x in verify if x.get("merchantId") == args.merchant_id}
    if status != 200 or len(assigned_ids) != len(product_ids) or not set(product_ids).issubset(assigned_ids):
        raise RuntimeError(f"verification failed: expected {len(product_ids)} unique assignments, found {len(assigned_ids)}")
    print(f"Replacement complete and verified: {len(assigned_ids)} merchant-owned products")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
