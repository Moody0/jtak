# Security & Contracts Verification Report (Requirements R1 & R2)

**Agent**: Security & Contracts Explorer (`explorer_security_contracts_1`)  
**Target Ecosystem**: `jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`  
**Date**: 2026-09-13  
**Status**: COMPLETE  

---

## 1. Observation

### R1. Security & Authorization Preflight Check

#### R1.1 Master OTP Elimination & Bypass Codes
1. **`jtak-backend-main/app/ApiControllers/V1/Authorization/OAuthTokenController.cs:214-220`**:
   The baseline unconditional bypass (`if (!request.Username.Contains("+90555555555")) { ... ChangePhoneNumberAsync ... }`) has been removed from the main execution path. However, lines 214-220 retain:
   ```csharp
   var isCodeValid = false;
   #if DEBUG
   if (_env.EnvironmentName == "Development" && request.Username.Contains("+90555555555"))
   {
       isCodeValid = request.Code == "123456" || request.Code == "1234";
   }
   #endif
   ```
   In Release configuration (`dotnet build -c Release`), the Roslyn compiler omits `#if DEBUG` blocks completely. In Debug builds, it is active only when `_env.EnvironmentName == "Development"`.
   The non-debug verification chain (lines 222-268) requires:
   - Step 1: `_userManager.VerifyChangePhoneNumberTokenAsync(user, request.Code, phone)`
   - Step 2: `_userManager.ChangePhoneNumberAsync(user, phone, request.Code)`
   - Step 3: Fallback check against `_smsLogService.Queryable()` within 30 minutes where `matchingLog.UserId == user.Id` or matching candidate phone numbers.

2. **CRITICAL DISCOVERY - Plaintext OTP Response in `AccountController.cs:325`**:
   In `jtak-backend-main/app/ApiControllers/V1/Authorization/AccountController.cs:285-326`:
   ```csharp
   [AllowAnonymous, HttpPost, Route("RegisterOrSignInByPhoneNumber")]
   public async Task<ActionResult<string>> RegisterOrSignInByPhoneNumber(PhoneNumberModel model)
   {
       // ... creates or retrieves user ...
       var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
       var msg = string.Format(_Account.SmsVerification, code);
       var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
       _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });
       await _unitOfWork.SaveChangesAsync();
       return code; // <--- Returns raw OTP token directly to unauthenticated client!
   }
   ```
   In `jtak-mobile-master/lib/src/core/controllers/user/user_provider.dart:66-70`:
   ```dart
   var res = await _api.postRequest('/Account/RegisterOrSignInByPhoneNumber', body, apiPrefex: apiPrefex);
   log('registerOrSignInByPhoneNumber : $res');
   if (res != null) {
     lastVerificationCode = res.toString().replaceAll('"', '').trim();
   }
   ```
   And in `jtak-mobile-master/lib/src/ui/pages/account/phone_code_page.dart:43` & `146`:
   ```dart
   _code = widget.autoFillCode ?? prov.lastVerificationCode ?? '';
   initialValue: _code.isNotEmpty ? _code : (userProvider.lastVerificationCode ?? ''),
   ```
   The backend API returns the generated SMS OTP directly in the HTTP JSON response body to any caller, allowing unauthenticated account takeover of any phone number.

3. **CRITICAL DISCOVERY - Hardcoded Admin Credentials in Delivery Driver App**:
   In `jtak-mobile-delivery-master/lib/src/core/controllers/user_provider.dart:68-83`:
   ```dart
   Future<void> promoteCurrentDriverToDelivery() async {
     try {
       final user = authService.user;
       if (user == null || user.id == null) return;
       final adminTokenRes = await _api.postRequest(
         '/connect/token',
         {
           "grant_type": "password",
           "username": "admin@jtak.app",
           "password": "P@ssw0rd",
           "scope": "offline_access profile roles phone email",
         },
         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
         apiPrefex: '',
       );
   ```
   This method is actively executed upon driver login in `jtak-mobile-delivery-master/lib/src/ui/pages/account/phone_code_page.dart:349`. Any user inspecting the app APK or network traffic can extract administrator credentials.
   (Note: Customer app `markets_provider.dart` and Warehouse app have no admin credentials).

4. **Proof of Delivery OTP Verification in Delivery OrdersController**:
   In `jtak-backend-main/app/ApiControllers/V1/Delivery/Orders/OrdersController.cs:556-565`:
   ```csharp
   var submittedOtp = request?.Otp ?? otp;
   var hasValidPhoto = !string.IsNullOrWhiteSpace(request?.PhotoUrl);
   if (!string.IsNullOrEmpty(currentOrder.DeliveryOtp))
   {
       bool otpValid = !string.IsNullOrWhiteSpace(submittedOtp) && submittedOtp.Trim() == currentOrder.DeliveryOtp.Trim();
       if (!otpValid && !hasValidPhoto)
       {
           return BadRequest(ApiErr.Create("رمز تأكيد التسليم غير صحيح. يرجى إدخال رمز التحقق أو التقاط صورة لتوثيق التسليم (PoD)."));
       }
   }
   ```
   Validation strictly enforces dynamic OTP matching or verified photo attachment; no hardcoded bypass code exists.

---

#### R1.2 IDOR Guardrails
1. **`jtak-backend-main/app/ApiControllers/V1/Customer/AddressController.cs`**:
   - `[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.CustomerPermission))]` at class level (line 22).
   - `GetMine()` (lines 52-56): Calls `_service.GetUserAddresses(User.GetUserId())`, strictly returning records belonging to caller JWT subject.
   - `Create(AddressDto model)` (lines 64-93): Overwrites any client-supplied user ID with `entity.UserId = uid.Value` (line 69).
   - `Edit(int id, AddressDto model)` (lines 102-113):
     ```csharp
     var entity = await _service.FindAsync(id);
     if (entity == null) return BadRequest("Not found!");
     var uid = User.GetUserId();
     if (uid == null || entity.UserId != uid.Value) return Forbid();
     ```
   - `Delete(int id)` (lines 145-156):
     ```csharp
     var entity = await _service.FindAsync(id);
     if (entity == null) return BadRequest("Not found!");
     var uid = User.GetUserId();
     if (uid == null || entity.UserId != uid.Value) return Forbid();
     ```

2. **`jtak-backend-main/app/ApiControllers/V1/Warehouse/Catalog/BatchesController.cs`**:
   - `[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]` at class level (line 22).
   - `Get()` (lines 46-73): Queries `merchantIds = await _merchantService.GetMerchantIds(userId.Value)`. Returns empty list if no merchant IDs found; all batch queries are scoped strictly to the merchant IDs owned by caller.
   - `GetAlerts()` (lines 79-94): Iterates solely over `merchantIds = await _merchantService.GetMerchantIds(userId.Value)`.
   - `GetById(int id)` (lines 100-113):
     ```csharp
     var merchantIds = await _merchantService.GetMerchantIds(userId.Value);
     if (!merchantIds.Contains(batch.MerchantId)) return Forbid();
     ```
   - `Create(CreateProductBatchDto dto)` (lines 136-152): Enforces `if (!merchantIds.Contains(dto.MerchantId)) return Forbid();`.
   - `AdjustStock(StockAdjustmentDto dto)` (lines 164-178): Fetches batch, validates `if (!merchantIds.Contains(batch.MerchantId)) return Forbid();`.
   - `GetByBarcode(string barcode)` (lines 119-130): Scopes query to `primaryMerchantId = merchantIds.FirstOrDefault()`.

---

#### R1.3 SignalR Telemetry Hub Authorization & Dispatch Policies
1. **`jtak-backend-main/app.Services/Hubs/TrackingHub.cs`**:
   - Class-level attribute: `[Authorize]` (line 11).
   - `JoinCourierRadar()` & `JoinFleetRadar()` (lines 40-56): Guarded by `[Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]`. Only administrative tokens can join the `courier_dispatch` broadcast group.
   - `JoinOrderTracking(int orderId)` (lines 18-32):
     ```csharp
     [Authorize]
     public async Task JoinOrderTracking(int orderId)
     {
         if (orderId <= 0) throw new HubException("Invalid order ID.");
         var user = Context.User;
         if (user?.Identity?.IsAuthenticated != true) throw new HubException("Unauthorized to track this order.");
         await Groups.AddToGroupAsync(Context.ConnectionId, $"order_{orderId}");
     }
     ```
     Observation: Any authenticated user can join `order_{orderId}` for any `orderId`. It does not verify whether `Context.User` is the customer who placed the order, the assigned driver, or an administrator.

---

#### R1.4 OpenIddict Key Persistence & Token Survivability
1. **`jtak-backend-main/app/Startup.cs:127-129`**:
   ```csharp
   services.AddSimpleServerOpenIddict();
   services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo("keys"));
   ```
   Persisted keys exist in `D:\work\jtak\jtak-backend-main\app\keys\` (5 XML key files present: `key-7441e810-....xml`, etc.).
2. **`jtak-backend-main/app/Helpers/StartUp/OpenIddictHelper.cs:120-143`**:
   ```csharp
   options.UseDataProtection();
   // ... X509Store production certificate loading is commented out ...
   options.AddDevelopmentEncryptionCertificate();
   options.AddDevelopmentSigningCertificate();
   ```
   Observation:
   - Because `options.UseDataProtection()` is used for token generation/validation, access tokens rely on the ASP.NET Core Data Protection stack whose keys are persisted to `keys/`.
   - However, `options.AddDevelopmentSigningCertificate()` and `options.AddDevelopmentEncryptionCertificate()` are used. In OpenIddict, development certificates are stored in the CurrentUser certificate store. If the server process runs under an IIS Application Pool without a loaded user profile (`LoadUserProfile = false`) or in ephemeral hosting, the development signing certificate is regenerated upon recycle, invalidating active tokens.
   - The directory path `new DirectoryInfo("keys")` is relative rather than absolute or rooted in `IWebHostEnvironment.ContentRootPath`.

---

### R2. End-to-End Contract & Data Flow Parity

#### R2.1 Order Status Enum Consistency & Status Code Inversion
1. **Backend `OrderStatus.cs` (`Modules.Orders.Entities`)**:
   - `OrderStatus`: `Pending = 0`, `Success = 1`
   - `OrderDetailStatus`: `Pending = 0`, `MerchantAccepted = 1`, `ShippingStarted = 2`, `Delivered = 3`, `MerchantRejected = 4`, `CustomerPending = 5`, `CustomerCanceled = 6`, `DeliveryCanceled = 7`.
2. **Dashboard `order-status.enum.ts` (`jtak-dashboard-main/src/app/pages/orders/models/`)**:
   - `OrderDetailStatus`: 0: `Pending`, 1: `MerchantAccepted`, 2: `ShippingStarted`, 3: `Delivered`, 4: `MerchantRejected`, 5: `CustomerPending`, 6: `CustomerCanceled`, 7: `DeliveryCanceled`.
   - `orders-list.component.ts:302-338` & `dashboard.component.ts:288-309`:
     - Delivered (`3`): Green badge / `تم التسليم` / `Delivered`
     - ShippingStarted (`2`): Blue/Info badge / `جاري التوصيل` / `In Transit`
     - Canceled (`4, 6, 7`): Red badge / `ملغي ...` / `Canceled`
     - Status inversion (Delivered vs Cancelled or Shipping vs Rejected) is completely eliminated.
3. **Customer App (`jtak-mobile-master`)**:
   - `order_status_enum.dart`: `0: pending`, `1: success`.
   - `order_details_status_enum.dart`: 0..7 matching backend 1:1.
4. **Warehouse App (`jtak-mobile-warehouse-master`)**:
   - `order_status_enum.dart`: `0: pending`, `1: success`.
   - `order_details_status_enum.dart`: 0..7 matching backend 1:1.
5. **CRITICAL DISCOVERY - Enum Mismatch in Delivery App (`jtak-mobile-delivery-master`)**:
   - In `jtak-mobile-delivery-master/lib/src/core/enums/order_details_status_enum.dart:3-52`:
     ```dart
     enum OrderDetailsStatus { pending, merchantAccepted, shipping, delivered, merchantRejected, customerPending, customerCanceled }
     // ...
     extension ParseEnumExtention on int {
       OrderDetailsStatus get parseOrderDetailsStatus {
         switch (this) {
           case 0: return OrderDetailsStatus.pending;
           case 1: return OrderDetailsStatus.merchantAccepted;
           case 2: return OrderDetailsStatus.shipping;
           case 3: return OrderDetailsStatus.delivered;
           case 4: return OrderDetailsStatus.merchantRejected;
           case 5: return OrderDetailsStatus.customerPending;
           case 6: return OrderDetailsStatus.customerCanceled;
           default:
             throw Exception('order details status not recognized');
         }
       }
     }
     ```
     `DeliveryCanceled = 7` is missing. If an order detail has status 7 (`DeliveryCanceled`), parsing throws an unhandled `Exception('order details status not recognized')` in the Delivery app.

---

#### R2.2 Customer Cart Item Cleanup
1. **Backend `CartController.cs:140-161`**:
   When reusing an existing pending cart for a customer:
   ```csharp
   var existingDetails = await _orderDetailService.Queryable()
                                                 .Where(x => x.OrderId == cart.Id)
                                                 .ToListAsync();
   foreach (var item in existingDetails)
   {
       _orderDetailService.Delete(item);
   }
   if (existingDetails.Count > 0)
   {
       await _uow.SaveChangesAsync();
   }
   ```
   All stale `OrderDetails` from earlier pending sessions are explicitly deleted before adding new items.
2. **Customer App `cart_provider.dart`**:
   - `submitOrder()` (line 414): Calls `await resetData()`, clearing memory list `localCartItems`, resetting `order`, resetting `count = 0`, and purging persistent `SharedPreferences` storage via `_removeLocalCart()`.
   - `replaceCartWithItem()` (lines 210-219): Explicitly clears existing items and storage before appending the new merchant's item.
   - `order_details_page.dart:1295-1313` (`_reorderAllItems`): Does not clear the cart prior to adding items; it adds each item via `cart.setToCart(...)` (merges with active cart).

---

#### R2.3 Product Review Entity Mapping (`ProductId`)
1. **Backend `Customer/ProductReviewsController.cs:129`**:
   In `Create(int orderId, CreateOrderReview model)`:
   ```csharp
   var reviews = orderDetails.Select(x => new ProductReview
   {
       ReviewerId = uid.Value,
       TextReview = model.TextReview,
       ProductId = x.ProductId, // Correctly references catalog product ID
       ProductTitle = x.ProductTitle,
       ProductImage = x.ProductImage,
       Rate = model.Rate
   });
   ```
   The previous defect (`ProductId = x.Id`) is fixed. Reviews link to catalog `ProductId`.
2. **CRITICAL DISCOVERY - IDOR Vulnerability on Review Deletion**:
   In `Customer/ProductReviewsController.cs:147-153`:
   ```csharp
   [HttpDelete]
   [Route("{id}")]
   public async Task<ActionResult<bool>> Delete(int id)
   {
       await _service.DeleteAsync(id);
       await _uow.SaveChangesAsync();
       return true;
   }
   ```
   The endpoint does NOT verify that `Review.ReviewerId == User.GetUserId()`. Any authenticated customer can delete any product review in the system.
3. **CRITICAL DISCOVERY - Mobile Review Deletion Parameter Inversion**:
   In `jtak-mobile-master/lib/src/ui/widgets/catalog/reviews_widgets.dart:55`:
   ```dart
   onPressed: () => Provider.of<ProductReviewProvider>(context, listen: false).delete(item.productId!),
   ```
   The UI passes `item.productId` instead of `item.id` to `delete()`. In `product_review_provider.dart:29`, this calls `DELETE /ProductReviews/{productId}`, attempting to delete a review whose primary key matches the catalog product ID.

---

#### R2.4 Dual-Broadcast SignalR Telemetry Streams
1. **Backend Broadcasts (`Delivery/Orders/OrdersController.cs`)**:
   - Lines 460-461:
     ```csharp
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierLocationUpdated", courierPayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetLocationUpdated", courierPayload);
     ```
   - Lines 496-497:
     ```csharp
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierDutyStatusChanged", statusPayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetDutyStatusChanged", statusPayload);
     ```
   - Lines 525-527:
     ```csharp
     await _trackingHub.Clients.Group($"order_{id}").SendAsync("OnLocationUpdated", livePayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnCourierLocationUpdated", livePayload);
     await _trackingHub.Clients.Group(TrackingHub.CourierDispatchGroup).SendAsync("OnFleetLocationUpdated", livePayload);
     ```
2. **Dashboard Listeners (`jtak-dashboard-main/src/app/pages/orders/services/signalr-tracking.service.ts:118-124`)**:
   ```typescript
   this.hubConnection.on('OnCourierLocationUpdated', (data: any) => {
     this.radarUpdatedSubject.next(data);
   });
   this.hubConnection.on('OnFleetLocationUpdated', (data: any) => {
     this.radarUpdatedSubject.next(data);
   });
   ```
   Both streams are registered and feed the `radarUpdated$` stream seamlessly.

---

## 2. Logic Chain

1. **R1.1 Logic**:
   - Baseline code bypassed OTP validation completely whenever `request.Username.Contains("+90555555555")`.
   - The current code wraps the test condition in `#if DEBUG ... #endif`. Under Release compilation (`-c Release`), the Roslyn preprocessor strips the block from the compiled binary.
   - Therefore, production builds enforce legitimate SMS code validation.
   - However, `AccountController.cs:325` explicitly returns `return code;`, exposing the generated OTP in plaintext over HTTP to unauthenticated callers.
   - Furthermore, `jtak-mobile-delivery-master` embeds hardcoded admin credentials `admin@jtak.app` / `P@ssw0rd` in `user_provider.dart:76-77`.

2. **R1.2 Logic**:
   - `AddressController.cs` assigns `entity.UserId = uid.Value` during creation and compares `entity.UserId != uid.Value` in `Edit` and `Delete`, returning `Forbid()` on mismatch.
   - `Warehouse/BatchesController.cs` resolves `merchantIds` from JWT caller ID and validates that `dto.MerchantId` or target batch `MerchantId` belongs to caller before executing queries or mutations.
   - Thus, IDOR guardrails in both controllers are strictly enforced.

3. **R1.3 Logic**:
   - `TrackingHub.cs` protects `JoinCourierRadar` and `JoinFleetRadar` with `Policy = nameof(AppPermissionKey.AdminPermission)`. Only verified admins can join courier dispatch.
   - However, `JoinOrderTracking(orderId)` only checks `user.Identity.IsAuthenticated`. It does not check if the caller owns the order, allowing any authenticated user to track any order's live SignalR updates if they know or enumerate the order ID.

4. **R1.4 Logic**:
   - `AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo("keys"))` persists master keys to disk.
   - However, OpenIddict server registers development signing and encryption certificates instead of a fixed production X.509 certificate.
   - If the Windows CurrentUser certificate store is wiped or unavailable to the app pool, OpenIddict regenerates the certificate upon restart, invalidating prior tokens.

5. **R2.1 Logic**:
   - Inspection of backend `OrderStatus.cs` and dashboard `order-status.enum.ts` confirms identical numeric indices (0: Pending through 7: DeliveryCanceled).
   - Dashboard mapping uses green for Delivered (3) and red for Cancelled (6, 7). No inversion exists.
   - Customer and Warehouse apps define all 8 values (0..7).
   - The Delivery Driver app omits index 7 (`deliveryCanceled`) and its parse method throws an exception for unknown values.

6. **R2.2 Logic**:
   - `CartController.cs` searches for an existing `Pending` order for `user.Id`, queries `_orderDetailService`, and deletes existing items prior to adding new items.
   - Mobile `CartProvider` triggers `resetData()` on checkout and `replaceCartWithItem()` on merchant switches, ensuring local state is cleared.

7. **R2.3 Logic**:
   - In `Customer/ProductReviewsController.cs:129`, `ProductId` is populated with `x.ProductId`.
   - `ProductReviewsController.cs:147` (`Delete`) omits the `ReviewerId == uid` ownership check, introducing an IDOR vulnerability.
   - In `reviews_widgets.dart:55`, the client passes `item.productId` instead of `item.id` to the delete method, causing mismatched ID lookups.

8. **R2.4 Logic**:
   - Backend `OrdersController.cs` fires both `OnCourierLocationUpdated` and `OnFleetLocationUpdated`.
   - Dashboard `signalr-tracking.service.ts` listens to both event names and passes payloads to the same subject.

---

## 3. Caveats

1. **Staging vs Production Environment for R1.1**: If a staging or test server is deployed using `Debug` configuration with `ASPNETCORE_ENVIRONMENT=Development`, the bypass at `OAuthTokenController.cs:215-220` remains active for `+90555555555`.
2. **IIS User Profile Configuration for R1.4**: Token survivability across IIS worker process recycles depends on the application pool setting `Load User Profile = True` because development certificates reside in the user profile certificate store.
3. **Live GPS in Customer App**: The customer Flutter app currently relies on polling `GET /Orders/{id}/LiveTrack` every 4 seconds rather than a persistent WebSocket SignalR connection, while the Admin dashboard uses the SignalR hub.

---

## 4. Conclusion

| Requirement | Description | Status | Critical Findings & Verdict |
| :--- | :--- | :--- | :--- |
| **R1.1** | Elimination of Master OTP & Hardcoded Bypasses | **DEFECTS FOUND** | 1. `#if DEBUG` eliminates bypass in Release, but bypass code remains in source for Development.<br>2. **HIGH**: `AccountController.cs:325` returns plaintext OTP in API response (`return code;`).<br>3. **CRITICAL**: `jtak-mobile-delivery-master/user_provider.dart:76` embeds hardcoded `admin@jtak.app` / `P@ssw0rd`. |
| **R1.2** | IDOR Guardrails in Address & Batches | **PASSED** | Caller ownership is strictly verified via JWT claims in both `AddressController.cs` and `Warehouse/BatchesController.cs`. |
| **R1.3** | SignalR Telemetry Authorization | **PARTIAL PASS** | Dispatch radar group is strictly restricted to Admins. `JoinOrderTracking(id)` requires auth but lacks per-order authorization. |
| **R1.4** | OpenIddict Key Persistence & Survivability | **PARTIAL PASS** | DataProtection keys persist in `keys/`. Token survivability across recycles is vulnerable if IIS app pool does not load user profile due to `AddDevelopmentSigningCertificate()`. |
| **R2.1** | Order Status Enum Parity & Absence of Inversion | **DEFECT FOUND** | Status inversion on dashboard is resolved. However, Delivery app (`order_details_status_enum.dart`) is missing `deliveryCanceled = 7` and throws runtime exception. |
| **R2.2** | Customer Cart Cleanup | **PASSED** | Pending cart details are properly purged in `CartController.cs:150-161` and client local storage is wiped upon submit and replace. |
| **R2.3** | Product Review Mapping (`ProductId`) | **DEFECTS FOUND** | `ProductId = x.ProductId` is fixed. However:<br>1. `ProductReviewsController.cs:147` lacks IDOR ownership check on delete.<br>2. Mobile `reviews_widgets.dart:55` passes `item.productId` instead of `item.id` to delete. |
| **R2.4** | Dual-Broadcast SignalR Streams | **PASSED** | Backend emits both `OnCourierLocationUpdated` and `OnFleetLocationUpdated`; dashboard registers and handles both. |

---

## 5. Verification Method

To independently verify all findings:

1. **Verify Release build elimination of `#if DEBUG`**:
   ```powershell
   cd D:\work\jtak\jtak-backend-main
   dotnet build -c Release
   ```
   Inspect IL or run a test sending `+90555555555` with code `1234` against a Release build to confirm `ForbidInvalidUsernamePassword` (400/403).

2. **Verify Plaintext OTP Response Leak**:
   Inspect line 325 of `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Authorization\AccountController.cs`. Verify return statement is `return code;`.

3. **Verify Hardcoded Admin Credentials**:
   Inspect lines 72-83 of `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\controllers\user_provider.dart`.

4. **Verify Delivery App Enum Exception**:
   Inspect line 3 of `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\enums\order_details_status_enum.dart` and confirm absence of `deliveryCanceled` and `case 7` in `parseOrderDetailsStatus`.

5. **Verify Product Review IDOR and Client Mapping Defect**:
   - Inspect lines 145-154 of `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Customer\ProductReviewsController.cs`.
   - Inspect line 55 of `D:\work\jtak\jtak-mobile-master\lib\src\ui\widgets\catalog\reviews_widgets.dart`.
