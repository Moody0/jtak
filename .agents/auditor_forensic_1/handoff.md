# Forensic Integrity Audit Report

**Auditor Archetype**: forensic_auditor  
**Working Directory**: `D:\work\jtak\.agents\auditor_forensic_1\`  
**Target Work Product**: JTAK Ecosystem Remediation (`jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`, `update_production_db.sql`)  
**Date**: 2026-09-13  
**Definitive Binary Verdict**: **INTEGRITY VIOLATION**

---

## 1. Observation

### 1.1 Authentication & Backdoor Forensics

#### Observation 1.1.1: Plaintext SMS OTP Return in Anonymous Endpoint (`AccountController.cs:325`)
In `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Authorization\AccountController.cs` lines 285–326:
```csharp
[AllowAnonymous, HttpPost, Route("RegisterOrSignInByPhoneNumber")]
public async Task<ActionResult<string>> RegisterOrSignInByPhoneNumber(PhoneNumberModel model)
{
    var user = await _userManager.Users.FirstOrDefaultAsync(x => x.UserName == model.PhoneNumber) ?? await _userManager.Users.FirstOrDefaultAsync(x => x.PhoneNumber == model.PhoneNumber);

    if (user == null)
    {
        user = new AppUser { UserName = model.PhoneNumber, PhoneNumber = model.PhoneNumber, IsActive = true };
        var result = await _userManager.CreateAsync(user);
        if (!result.Succeeded) return BadRequest(result);
        result = await _userManager.AddToRoleAsync(user, AppRoleName.Customer.ToString());
        if (!result.Succeeded) return BadRequest(result);
        user = await _userManager.FindByPhoneNumberAsync(model.PhoneNumber);
    }
    var waitTimeInSecs = 0;
    if (waitTimeInSecs > 0) return BadRequest($"You need to wait {waitTimeInSecs}s");

    var code = await _userManager.GenerateChangePhoneNumberTokenAsync(user, model.PhoneNumber);
    var msg = string.Format(_Account.SmsVerification, code);

    var response = await _notificationService.SendSmsNotification(model.PhoneNumber, msg);
    _smsLogService.Insert(new SmsLog { UserId = user.Id, Code = code, Text = msg, Response = response });

    await _unitOfWork.SaveChangesAsync();

    return code; // <--- Raw OTP token returned directly to unauthenticated caller!
}
```
Direct inspection of compiled Release binary `D:\work\jtak\jtak-backend-main\App\bin\Release\net6.0\App.dll` confirms that method `<RegisterOrSignInByPhoneNumber>d__16` contains 1,853 bytes of IL code with NO `#if DEBUG` guard. The return of `code` is unconditionally compiled into production binaries.

#### Observation 1.1.2: Customer Mobile App Exploitation of Plaintext OTP
In `D:\work\jtak\jtak-mobile-master\lib\src\core\controllers\user\user_provider.dart` lines 62–72:
```dart
Future<void> registerOrSignInByPhoneNumber(String phoneNumber) async {
  await loadBaseData(
    loadBody: () async {
      Map<String, String> body = {"phoneNumber": phoneNumber};
      var res = await _api.postRequest('/Account/RegisterOrSignInByPhoneNumber', body, apiPrefex: apiPrefex);
      log('registerOrSignInByPhoneNumber : $res');
      if (res != null) {
        lastVerificationCode = res.toString().replaceAll('"', '').trim();
      }
    },
  );
}
```
And in `D:\work\jtak\jtak-mobile-master\lib\src\ui\pages\account\phone_code_page.dart` lines 42–44 and 144–152:
```dart
final prov = locator<UserProvider>();
_code = widget.autoFillCode ?? prov.lastVerificationCode ?? '';
...
CodeInputWidget(
  codeLength: 6,
  initialValue: _code.isNotEmpty ? _code : (userProvider.lastVerificationCode ?? ''),
  onChange: (code) => _code = code,
  onEnd: (code) {
    _code = code;
    _loginFun();
  },
),
```
The customer app intercepts the returned raw OTP string from the API response and automatically populates it into the verification input form.

#### Observation 1.1.3: Hardcoded Admin Credentials & Privilege Escalation in Delivery App
In `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\controllers\user_provider.dart` lines 68–107:
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
    final adminToken = adminTokenRes['access_token'];
    if (adminToken != null) {
      final updateBody = {
        "id": user.id,
        "firstName": user.fullName ?? "كابتن",
        "lastName": "توصيل",
        "fullName": user.fullName ?? "كابتن توصيل",
        "phoneNumber": (user.phoneNumber ?? "").replaceAll("+963", ""),
        "countryPhoneCode": "+963",
        "role": 3,
        "isActive": true,
        "gender": 0,
      };
      await _api.putRequest(
        '/Admin/Users/${user.id}',
        updateBody,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
        apiPrefex: SolApi.apiVersionPrefex,
      );
      authService.user?.role = 3;
    }
  } catch (e) {
    debugPrint('Auto promote error: $e');
  }
}
```
In `D:\work\jtak\jtak-mobile-delivery-master\lib\src\ui\pages\account\phone_code_page.dart` lines 347–352:
```dart
if (authenticationService.user != null) {
  if (authenticationService.user!.role == null || authenticationService.user!.role != kDeliveryRole) {
    await userProvider.promoteCurrentDriverToDelivery();
  }
  InitWidget.restartApp(context);
}
```
This method automatically executes on driver authentication, using hardcoded administrator credentials to elevate permissions via the admin API.

#### Observation 1.1.4: OAuthTokenController Bypass Analysis (Release vs Debug)
In `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Authorization\OAuthTokenController.cs` lines 214–220:
```csharp
var isCodeValid = false;
#if DEBUG
if (_env.EnvironmentName == "Development" && request.Username.Contains("+90555555555"))
{
    isCodeValid = request.Code == "123456" || request.Code == "1234";
}
#endif
```
Forensic IL metadata disassembly of `<Exchange>d__11.MoveNext` across build artifacts revealed:
- **Release configuration** (`App\bin\Release\net6.0\App.dll`): IL method size is 5,305 bytes. User string scan for opcode `ldstr` confirms that strings `"Development"`, `"+90555555555"`, `"123456"`, and `"1234"` are **100% absent**. The Roslyn compiler completely eliminated lines 215–220.
- **Debug configuration** (`App\bin\Debug\net6.0\App.dll`): IL method size is 6,799 bytes. User string scan confirms presence of `"Development"`, `"+90555555555"`, `"123456"`, and `"1234"`.

#### Observation 1.1.5: Hardcoded Credentials Scan Across Codebases
- `D:\work\jtak\jtak-backend-main\app\Setup\SeedUsers.cs:27`:
  `private async Task CreateUserInRole(string email, AppRoleName role, string password = "P@ssw0rd")`
- `D:\work\jtak\jtak-mobile-master\lib\src\ui\pages\account\login_email_page.dart:26`:
  `String email = 'admin@ecommerce.kuarkz.com', password = "P@ssw0rd";`
- `D:\work\jtak\jtak-mobile-delivery-master\lib\src\ui\pages\account\login_page.dart:37-38`:
  `_phoneController.text = '09555555553'; _passwordController.text = 'P@ssw0rd';`
- `D:\work\jtak\jtak-mobile-delivery-master\lib\src\ui\pages\account\phone_code_page.dart:340`:
  `if (codeToSend == '123456' && activeCode != null && activeCode.isNotEmpty) { codeToSend = activeCode; }`

---

### 1.2 IDOR & Authorization Forensics

#### Observation 1.2.1: Unauthenticated IDOR Vulnerability in Product Review Deletion
In `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Customer\ProductReviewsController.cs` lines 146–153:
```csharp
/// <summary>
/// Delete product review
/// </summary>
/// <returns></returns>
[HttpDelete]
[Route("{id}")]
public async Task<ActionResult<bool>> Delete(int id)
{
    await _service.DeleteAsync(id);
    await _uow.SaveChangesAsync();
    return true;
}
```
Class-level declaration:
```csharp
[Route("api/v{version:apiVersion}/Customer/[controller]")]
[ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
[ApiVersion("1")]
public class ProductReviewsController : SolApiController
```
The controller lacks class-level `[Authorize]` attributes. The `Delete(int id)` action lacks `[Authorize]`, performs no identity resolution (`User.GetUserId()`), and does not compare `Review.ReviewerId` to the caller. Any unauthenticated or authenticated entity can delete any review in the system.

#### Observation 1.2.2: Missing Per-Order Authorization in SignalR `TrackingHub.cs`
In `D:\work\jtak\jtak-backend-main\app.Services\Hubs\TrackingHub.cs` lines 17–32:
```csharp
[Authorize]
public async Task JoinOrderTracking(int orderId)
{
    if (orderId <= 0)
    {
        throw new HubException("Invalid order ID.");
    }

    var user = Context.User;
    if (user?.Identity?.IsAuthenticated != true)
    {
        throw new HubException("Unauthorized to track this order.");
    }

    await Groups.AddToGroupAsync(Context.ConnectionId, $"order_{orderId}");
}
```
While `JoinCourierRadar()` is properly guarded by `[Authorize(Policy = nameof(AppPermissionKey.AdminPermission))]`, `JoinOrderTracking(int orderId)` only checks `user.Identity.IsAuthenticated`. It does NOT verify whether the caller is the customer who placed `orderId`, the assigned courier, or an administrator. Any authenticated user can eavesdrop on live coordinates, customer addresses, and order delivery events for any order.

#### Observation 1.2.3: Verification of AddressController and BatchesController IDOR Guards
- `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Customer\AddressController.cs`:
  - Class decorated with `[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.CustomerPermission))]`.
  - `Create`: Forces `entity.UserId = uid.Value` (line 69).
  - `Edit`: Validates `if (uid == null || entity.UserId != uid.Value) return Forbid();` (line 110–113).
  - `Delete`: Validates `if (uid == null || entity.UserId != uid.Value) return Forbid();` (line 153–156).
  - **Verdict on AddressController**: Clean and protected.
- `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Warehouse\Catalog\BatchesController.cs`:
  - Class decorated with `[Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.MerchantPermission))]`.
  - Resolves `merchantIds = await _merchantService.GetMerchantIds(userId.Value)`.
  - `Get`, `GetAlerts`, `GetById`, `Create`, and `AdjustStock` strictly enforce that operations pertain only to merchant IDs belonging to the authenticated caller.
  - **Verdict on BatchesController**: Clean and protected.

---

### 1.3 Contract & Enum Parity Forensics

#### Observation 1.3.1: Delivery App Enum Mismatch (`OrderDetailsStatus`)
In `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\enums\order_details_status_enum.dart` lines 3–21:
```dart
enum OrderDetailsStatus { pending, merchantAccepted, shipping, delivered, merchantRejected, customerPending, customerCanceled }

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
The backend `OrderDetailStatus` enum defines `DeliveryCanceled = 7`. The Delivery Driver app omits `deliveryCanceled = 7`. When an order item with status 7 is parsed, the Delivery app crashes with an unhandled exception (`Exception('order details status not recognized')`).

#### Observation 1.3.2: Mobile Review Deletion Parameter Inversion
In `D:\work\jtak\jtak-mobile-master\lib\src\ui\widgets\catalog\reviews_widgets.dart` line 55:
```dart
onPressed: () => Provider.of<ProductReviewProvider>(context, listen: false).delete(item.productId!),
```
The widget passes `item.productId` rather than `item.id` to the delete handler, dispatching a delete request targeting the catalog product ID instead of the review's primary key.

---

### 1.4 Database Migration & Schema Authenticity

#### Observation 1.4.1: Inspection of `update_production_db.sql`
- File: `D:\work\jtak\update_production_db.sql` (4,066 lines, 136,001 bytes).
- Automated parity check: 32 EF Core C# migrations match 32 migration blocks in the script (100% 1:1 match).
- Transactions: Exactly 32 `START TRANSACTION;` and 32 `COMMIT;` blocks; zero `ROLLBACK;`.
- Tables: Exactly **0** `DROP TABLE` statements.
- Column modifications: 38 column drops correspond to EF Core model evolution.
- Idempotency: All schema statements are wrapped in stored procedures guarded by `IF NOT EXISTS (SELECT 1 FROM __EFMigrationsHistory WHERE MigrationId = '...')`.
- **Verdict on Database Script**: Authentically generated from EF Core history without destructive drops or syntax circumventions.

---

### 1.5 Terminology & Localization Forensics

#### Observation 1.5.1: Deep Obfuscation & Encoding Scan for Prohibited Arabic Word ("أسطول")
A comprehensive scan was conducted across all text-based files in the entire ecosystem checking for:
1. Normalized Arabic root `ا?سطول` and `ا?ساطيل` (with all diacritics, tatweel `\u0640`, zero-width joiners `\u200C`, `\u200D`, and zero-width spaces stripped, and all Alef forms normalized).
2. Unicode escape sequences (`\u0633\u0637\u0648\u0644`).
3. Base64 encoded byte patterns (`2KPYs9i3`, `2KfYs9i3`).
4. Character code arrays (`1587, 1591, 1608, 1604`).
- **Results**:
  - Codebases (`jtak-backend-main`, `jtak-dashboard-main`, `jtak-mobile-master`, `jtak-mobile-delivery-master`, `jtak-mobile-warehouse-master`): **0 matches**.
  - Localization files (`ar.json`, `en.json`, `ar.ts`, `en.ts`, `*.resx`): **0 matches**.
  - Database SQL scripts (`update_production_db.sql`): **0 matches**.
  - The term appeared strictly in project requirement specifications and audit documentation (`ORIGINAL_REQUEST.md`, `AUDIT_REPORT.md`, `REMEDIATION_PLAN.md`, and agent audit reports) defining the compliance rule.
- **Verdict on Terminology**: 100% compliant. Zero occurrences of the prohibited term or disguised encodings exist in application code.

---

## 2. Logic Chain

1. **Premise 1 (Authentic Security)**: A software system must enforce authentication and authorization at the server boundary without hardcoded backdoors, plaintext credential leaks, or unauthorized privilege escalation.
2. **Premise 2 (Empirical Findings in Authentication)**:
   - Observation 1.1.1 demonstrates that `AccountController.cs:325` returns the raw SMS OTP token in the HTTP response body of an unauthenticated endpoint (`[AllowAnonymous]`).
   - Observation 1.1.2 proves that the Customer Flutter app relies on this leak to autofill the verification code without requiring SMS delivery.
   - Observation 1.1.3 proves that the Delivery Captain app embeds hardcoded administrator credentials (`admin@jtak.app` / `P@ssw0rd`) and actively uses them to grant driver permissions to unauthorized users.
   - Observation 1.1.5 proves that `P@ssw0rd` and `123456` remain embedded across multiple files.
3. **Premise 3 (Empirical Findings in IDOR & Authorization)**:
   - Observation 1.2.1 demonstrates that `ProductReviewsController.cs:147` exposes an unauthenticated review deletion endpoint without verifying ownership.
   - Observation 1.2.2 proves that `TrackingHub.cs:18` allows any authenticated user to join arbitrary order tracking streams without ownership or assignment checks.
4. **Premise 4 (Empirical Findings in Contract Consistency)**:
   - Observation 1.3.1 demonstrates that the Delivery app lacks enum index 7 (`DeliveryCanceled`), throwing unhandled runtime exceptions when encountering canceled order items.
5. **Deductive Conclusion**:
   The presence of plaintext OTP leaks in the public API, hardcoded administrative credentials used for client-side privilege escalation, unauthenticated IDOR endpoints, unauthorized SignalR telemetry access, and broken enum handling violates the core integrity and security standards required for pre-production sign-off.
   Consequently, the work product cannot be certified as clean and MUST be rejected.

---

## 3. Caveats

1. **Release Binary `#if DEBUG` Behavior**: The bypass in `OAuthTokenController.cs:215-220` is stripped in Release builds by the Roslyn compiler. However, the presence of the bypass in the source code remains an integrity risk if staging or testing servers are deployed under Debug configuration with `Development` environment settings.
2. **OpenIddict Key Storage**: Master DataProtection keys persist in `keys/`, but production stability requires binding OpenIddict to an explicit X.509 certificate rather than development certificates in the Windows user certificate store.
3. **Double-Entry Accounting & Migrations**: The accounting ledger service, inventory batch tracking, and database migration scripts (`update_production_db.sql`) are verified to be mathematically and architecturally sound with 100% EF Core migration parity. The rejection verdict is driven strictly by the authentication, authorization, and backdoor violations.

---

## 4. Conclusion

### Final Binary Verdict: **INTEGRITY VIOLATION**

The JTAK ecosystem work product fails the forensic integrity audit due to confirmed security defects, embedded backdoors, and broken authorization guardrails:

| Category | Finding | File & Line | Severity |
|---|---|---|---|
| **Authentication Leak** | Plaintext SMS OTP returned in public API response body | `AccountController.cs:325` | **CRITICAL** |
| **Hardcoded Credentials** | Embedded admin credentials (`admin@jtak.app` / `P@ssw0rd`) used for client auto-promotion | `jtak-mobile-delivery-master/.../user_provider.dart:76-77` | **CRITICAL** |
| **IDOR Vulnerability** | Unauthenticated review deletion endpoint lacking ownership checks | `ProductReviewsController.cs:147-153` | **HIGH** |
| **Telemetry IDOR** | SignalR `JoinOrderTracking` permits tracking arbitrary order streams without authorization | `TrackingHub.cs:18-32` | **HIGH** |
| **Contract Crash** | Missing `deliveryCanceled = 7` enum causing unhandled exceptions in Delivery app | `order_details_status_enum.dart:3-21` | **HIGH** |
| **Client Parameter Defect** | Review deletion UI passes `productId` instead of review primary key `id` | `reviews_widgets.dart:55` | **MEDIUM** |
| **Residual Test Secret** | Legacy email login page contains hardcoded admin credentials | `login_email_page.dart:26` | **MEDIUM** |

---

## 5. Verification Method

To independently reproduce and verify every finding:

1. **Verify Plaintext OTP Response**:
   Inspect `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Authorization\AccountController.cs` line 325:
   Confirm `return code;` terminates `RegisterOrSignInByPhoneNumber`.
2. **Verify Hardcoded Admin Credentials in Delivery App**:
   Inspect `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\controllers\user_provider.dart` lines 72–83:
   Confirm `username: "admin@jtak.app"` and `password: "P@ssw0rd"` are transmitted to `/connect/token`.
3. **Verify Product Review Deletion IDOR**:
   Inspect `D:\work\jtak\jtak-backend-main\app\ApiControllers\V1\Customer\ProductReviewsController.cs` lines 146–153:
   Confirm method `Delete(int id)` lacks `[Authorize]` and lacks `ReviewerId` validation.
4. **Verify SignalR Hub Telemetry Authorization Gap**:
   Inspect `D:\work\jtak\jtak-backend-main\app.Services\Hubs\TrackingHub.cs` lines 18–32:
   Confirm `JoinOrderTracking(int orderId)` adds connection to `order_{orderId}` without checking caller ownership or order assignment.
5. **Verify Delivery App Enum Exception**:
   Inspect `D:\work\jtak\jtak-mobile-delivery-master\lib\src\core\enums\order_details_status_enum.dart` lines 3–21:
   Confirm absence of `deliveryCanceled = 7` in enum definition and switch block.
6. **Verify Roslyn Release Binary Stripping of `#if DEBUG`**:
   Run the inspector tool:
   ```powershell
   dotnet run --project D:\work\jtak\.agents\auditor_forensic_1\inspector
   ```
   Confirm output proves strings `"Development"`, `"+90555555555"`, `"123456"`, and `"1234"` are omitted in Release `App.dll`, but present in Debug `App.dll`.
