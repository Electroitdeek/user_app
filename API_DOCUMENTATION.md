# Adhisaat Health Care — Complete API Documentation

> **Base URL:** `https://adhisaat.com/api` (Production) / `https://dev.adhisaat.com/api` (Development)  
> **Protocol:** HTTPS  
> **Headers:**
> - `Authorization`: `Bearer <TOKEN>` (Required for authenticated endpoints)
> - `Accept`: `application/json` (Required)
> - `cityAdminId`: `<CITY_ADMIN_ID>` (Header passed dynamically after location check)

---

## Table of Contents
1. [Overview & Authentication](#1-overview--authentication)
2. [Common / Shared Endpoints](#2-common--shared-endpoints)
3. [User (Patient) Side Endpoints](#3-user-patient-side-endpoints)
   - [Auth & Profile](#user-auth--profile)
   - [Addresses](#user-addresses)
   - [Family Members](#user-family-members)
   - [Services & Availability](#user-services--availability)
   - [Bookings & Service Requests](#user-bookings--service-requests)
   - [Payments & Installments](#user-payments--installments)
   - [Health Records](#user-health-records)
   - [User Wallet](#user-wallet)
   - [Rating & Support Tickets](#user-rating--support-tickets)
4. [Service Provider Side Endpoints](#4-service-provider-side-endpoints)
   - [Provider Registration & Onboarding](#provider-registration--onboarding)
   - [Provider Profile & Documents](#provider-profile--documents)
   - [Duty & Availability Management](#provider-duty--availability-management)
   - [Service Requests / Bookings Flow](#provider-service-requests--bookings-flow)
   - [Earnings & Wallet Withdrawals](#provider-earnings--wallet-withdrawals)
   - [Bank Details](#provider-bank-details)
   - [Registration Fee Payment](#provider-registration-fee-payment)
5. [Error Handling & Status Codes](#5-error-handling--status-codes)

---

## 1. Overview & Authentication

Authentication is handled via mobile OTP verification. Upon successful verification, the API issues a Bearer JWT Token (`access_token` / `token`).

All API requests MUST include:
```http
Authorization: Bearer <YOUR_ACCESS_TOKEN>
Accept: application/json
```

---

## 2. Common / Shared Endpoints

### 2.1 Send OTP
Initiates mobile OTP verification for login or registration.

- **Endpoint:** `POST /send-otp`
- **Content-Type:** `multipart/form-data` or `application/x-www-form-urlencoded`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `mobile_number` | String | Yes | 10-digit mobile number |
  | `purpose` | String | Yes | Purpose of OTP, e.g. `login` |
  | `resend` | String | No | Pass `"1"` if resending OTP, else `"0"` |

- **Response:**
  ```json
  {
    "status": true,
    "message": "OTP sent successfully",
    "otp": "1234" // Only in debug environment
  }
  ```

---

### 2.2 Verify OTP
Verifies the OTP entered by the user and returns an access token.

- **Endpoint:** `POST /verify-otp`
- **Content-Type:** `multipart/form-data`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `mobile_number` | String | Yes | Mobile number |
  | `otp` | String | Yes | 4-digit or 6-digit OTP code |
  | `purpose` | String | Yes | `login` |

- **Response:**
  ```json
  {
    "status": true,
    "message": "OTP verified successfully",
    "token": "131|eyJhbGciOi...",
    "user": {
      "id": 42,
      "name": "John Doe",
      "mobile_number": "9876543210",
      "roles": [
        { "id": 2, "name": "customer" }
      ]
    }
  }
  ```

---

### 2.3 Logout
Logs out the user and revokes the device session.

- **Endpoint:** `POST /auth/logout`
- **Headers:** `Authorization: Bearer <TOKEN>`
- **Parameters (JSON Body):**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `device_id` | String | Yes | Device unique ID (e.g. `AND-abcd1234` or `IOS-xyz567`) |

- **Response:**
  ```json
  {
    "status": true,
    "message": "Logged out successfully"
  }
  ```

---

### 2.4 Save FCM Device Token
Registers the Firebase Cloud Messaging device token for push notifications.

- **Endpoint:** `POST /auth/save-device-token`
- **Headers:** `Authorization: Bearer <TOKEN>`
- **Parameters (JSON Body):**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `device_token` | String | Yes | FCM Registration Token |
  | `device_id` | String | Yes | Device unique identifier |
  | `device_type` | String | Yes | `android` or `ios` |
  | `user_type` | String | Yes | `customer` or `service_provider` |

- **Response:**
  ```json
  {
    "status": true,
    "message": "Device token saved successfully"
  }
  ```

---

### 2.5 Get Auth Profile
Fetches current authenticated user/provider profile data.

- **Endpoint:** `GET /auth/profile`
- **Headers:** `Authorization: Bearer <TOKEN>`
- **Response:** Profile details object containing user ID, role, personal info, addresses, etc.

---

### 2.6 Fetch Dropdown Options
Fetches master data options for dropdown selections (genders, qualifications, document types, blood groups, relationship types).

- **Endpoint:** `GET /dropdown`
- **Response:** Master dropdown lists for app initialization.

---

### 2.7 Check Service Availability
Checks if health care services are available in a specific zipcode.

- **Endpoint:** `GET /check-service-availability`
- **Query Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `zipcode` | String | Yes | Pincode / Zip code to verify |
  | `exclude_man_machine_services` | String | No | Set to `"1"` to exclude equipment services |

- **Response:**
  ```json
  {
    "status": true,
    "data": {
      "is_available": true,
      "city_admin": {
        "id": 2,
        "name": "Jaipur Admin",
        "emergency_contact_number1": "917023221110"
      }
    },
    "server_time": {
      "current_date_time": "2026-08-27 18:44:35",
      "timezone": "Asia/Kolkata"
    }
  }
  ```

---

### 2.8 Consents & Legal Documents
Fetches terms, privacy policies, or consent forms.

- **Endpoint:** `POST /consents`
- **Parameters (Multipart):**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `consent_type` | String | Yes | `terms`, `privacy`, `registration`, etc. |
  | `city_admin_id` | String | No | City Admin ID |

---

### 2.9 FAQs & System Settings
- `GET /get-system-settings` — Fetches global app config, support phone numbers, play store URLs.
- `POST /faqs` — Fetches FAQ questions & answers based on `user_type`.
- `GET /promo-codes` — Fetches active promotional discount codes.

---

## 3. User (Patient) Side Endpoints

<a name="user-auth--profile"></a>
### 3.1 Customer Registration & Profile Update

#### Register Customer
- **Endpoint:** `POST /register/customer`
- **Content-Type:** `multipart/form-data`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `name` | String | Yes | Full Name |
  | `mobile_number` | String | Yes | 10-digit Mobile |
  | `email` | String | No | Email address |
  | `gender` | String | Yes | `male`, `female`, `other` |
  | `date_of_birth` | String | No | Date of Birth (`YYYY-MM-DD`) |
  | `referral_code` | String | No | Referral code |

#### Validate Referral Code
- **Endpoint:** `POST /register/customer/validate-referral-code`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `referral_code` | String | Yes | Referral code to validate |
  | `user_type` | String | No | `customer` or `service_provider` |

#### Update Customer Profile
- **Endpoint:** `POST /customer/update-profile`
- **Parameters (Multipart):**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `name` | String | No | Full Name |
  | `email` | String | No | Email Address |
  | `whatsapp_number` | String | No | WhatsApp Number |
  | `gender` | String | No | Gender |
  | `date_of_birth` | String | No | Date of Birth |
  | `blood_group` | String | No | Blood Group |
  | `profile_image` | File | No | Image file |

---

<a name="user-addresses"></a>
### 3.2 Address Management

- `GET /customer/addresses` — List user saved addresses.
- `POST /customer/address-addUpdate` — Add or Edit Address.
  - **Parameters (Multipart):**
    `id` (optional for edit), `address_line_1`, `address_line_2`, `landmark`, `city`, `state`, `pincode`, `latitude`, `longitude`, `is_default` (`"1"`/`"0"`), `address_type` (`"home"`/`"work"`/`"other"`).
- `POST /customer/address-delete/{id}` — Delete saved address.

---

<a name="user-family-members"></a>
### 3.3 Family Member Management

- `GET /customer/family-members` — List customer family members.
- `POST /customer/family-members/save` — Add/Update family member.
  - **Parameters (Multipart):** `id` (optional), `full_name`, `relation` (e.g. `Father`, `Mother`, `Spouse`), `gender`, `date_of_birth`, `blood_group`, `mobile_number`.
- `POST /customer/family-members-delete/{id}` — Delete family member.

---

<a name="user-services--availability"></a>
### 3.4 Service Catalogue & Provider Discovery

- `GET /get-service-categories` — Fetch all main service categories (e.g. Nursing, Physiotherapy, Attendant, Medical Equipment).
- `GET /get_service_categories_with_price/{id}` — Fetch subcategories and rate card pricing for category ID.
- `POST /customer/find-nearby-available-providers` — Find nearby health care providers.
  - **Parameters:** `latitude`, `longitude`, `service_category_id`, `sub_category_id`, `gender_preference`.

---

<a name="user-bookings--service-requests"></a>
### 3.5 Bookings & Service Requests

#### Create Regular Service Request
- **Endpoint:** `POST /customer/service-requests-create`
- **Content-Type:** `multipart/form-data`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `service_category_id` | String/Int | Yes | Main Service Category ID |
  | `service_sub_category_id` | String/Int | Yes | Sub-Category ID |
  | `address_id` | String/Int | Yes | Saved Address ID |
  | `family_member_id` | String/Int | No | Family Member ID (if booking for family) |
  | `start_date` | String | Yes | `YYYY-MM-DD` |
  | `start_time` | String | Yes | `HH:mm` |
  | `service_mode` | String | Yes | `live_in`, `visit`, `hourly`, `daily`, `monthly` |
  | `duration_hours` | String | No | Hours per visit |
  | `duration_days` | String | No | Total number of days |
  | `gender_preference` | String | No | `male`, `female`, `all` |
  | `scheduled_dates[i]` | Array | No | Array of dates for multi-day booking |
  | `special_instructions` | String | No | Patient condition or special instructions |
  | `promo_code` | String | No | Discount promocode |

#### Create Emergency Service Request
- **Endpoint:** `POST /customer/emergency-service-requests-create`
- **Parameters (Multipart):** `service_procedure_id`, `address_id`, `latitude`, `longitude`, `start_date`, `start_time`, `duration_hours`, `search_radius_km`.

#### View Service Requests & Details
- `POST /customer/service-requests` — Fetch user booking history list.
  - **Body:** `page`, `per_page`, `request_status` (`accepted`, `in_progress`, `completed`, `cancelled`).
- `POST /customer/service-requests-details` — Get single request details.
  - **Body:** `service_request_id` or `booking_id`.
- `POST /customer/sub-block-detail` — View specific duty session/sub-block breakdown.

#### Cancellation Preview & Session Cancel
- `POST /customer/cancellation-preview` — Calculate refund amount & penalty before cancelling.
  - **Body:** `service_request_id`, `sub_block_ids[]` (optional for single session cancel).
- `POST /customer/service-requests-cancel` — Cancel entire booking or specific sub-blocks.
  - **Body:** `service_request_id`, `sub_block_ids[]`, `reason`.

---

<a name="user-payments--installments"></a>
### 3.6 Payments & Installments

- **Apply Promocode:** `POST /auth/payments/apply-promocode`
  - Parameters: `promocode`, `amount`, `service_category_id`.
- **Initiate Payment:** `POST /auth/payments/initiate` or `POST /auth/payments/reguler-booking-payment-initiate`
  - Parameters: `service_request_id`, `amount`, `payment_method`, `installment_type`.
  - Response: `razorpay_order_id`, `amount`, `currency`, `razorpay_key`.
- **Pay Pending Installments:** `POST /customer/service-requests-pay-pending-installments`
  - Parameters: `service_request_id`, `installment_id`, `amount`.
- **Confirm Zero-Amount Booking:** `POST /customer/service-requests-booking-confirm`
  - Parameters: `service_request_id`.
- **Verify Razorpay Payment:** `POST /auth/payments/verify`
  - Parameters: `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature`, `amount`.
- **Failed Payment Notification:** `POST /auth/payments/failed`
  - Parameters: `razorpay_order_id`.
- **User Payment History & Invoices:**
  - `GET /customer/payments` — Payment history list.
  - `GET /customer/invoice-download` — Download PDF invoice (`booking_id` or `payment_id`).

---

<a name="user-health-records"></a>
### 3.7 Health Records & Medical Reports

- `GET /auth/health-records` — List uploaded medical reports (`family_member_id` query param optional).
- `POST /auth/health-records/save` (Multipart): `id` (optional), `record_type` (Lab Report, Prescription, Discharge Summary), `record_name`, `record_date`, `notes`, `file_path` (File).
- `POST /auth/health-records/delete` (Multipart): `id`.

---

<a name="user-wallet"></a>
### 3.8 User Wallet

- `POST /auth/add-money-to-wallet-initiate` — Initiate wallet top-up payment (`amount`).
- `GET /auth/wallet-transections` — View wallet balance & transaction statement.

---

<a name="user-rating--support-tickets"></a>
### 3.9 Rating, Reviews & Support Tickets

- **Submit Provider Rating:** `POST /customer/submit-rating`
  - Parameters (Multipart): `service_request_id`, `service_provider_id`, `rating` (1 to 5), `review_comment`.
- **Support Tickets:**
  - `GET /customer/support-tickets` — List support tickets.
  - `POST /customer/support-tickets-create` — Open ticket (`subject`, `category`, `message`, `attachment`).
  - `GET /customer/support-tickets-details?ticket_id=X` — View ticket detail & messages.
  - `POST /customer/support-tickets-send-message` — Reply to ticket (`ticket_id`, `message`, `attachment`).

---

## 4. Service Provider Side Endpoints

<a name="provider-registration--onboarding"></a>
### 4.1 Provider Registration & Onboarding

- **Endpoint:** `POST /register/service-provider`
- **Content-Type:** `multipart/form-data`
- **Parameters:**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `name` | String | Yes | Provider full name |
  | `mobile_number` | String | Yes | 10-digit mobile |
  | `whatsapp_number` | String | No | WhatsApp mobile |
  | `email` | String | No | Email address |
  | `date_of_birth` | String | Yes | `YYYY-MM-DD` |
  | `gender` | String | Yes | `male` or `female` |
  | `blood_group` | String | No | Blood Group |
  | `highest_qualification` | String | Yes | e.g. `B.Sc Nursing`, `GNM`, `D.Pharma` |
  | `professional_registration_number` | String | No | Council Registration Number |
  | `council_board_name` | String | No | Nursing Council / Medical Board name |
  | `total_experience` | String | Yes | Total experience in years |
  | `previous_workplace` | String | No | Hospital or Clinic name |
  | `preferred_working_area` | String | No | Locality / City |
  | `about` | String | No | Bio summary |
  | `aadhar_no` | String | Yes | 12-digit Aadhaar Card Number |
  | `pan_number` | String | No | 10-character PAN |
  | `duty_type[i]` | Array | Yes | `hourly`, `daily`, `monthly`, `live_in`, `visit` |
  | `skills[i]` | Array | No | Specialized healthcare skills |
  | `profile_image` | File | Yes | Profile Photo |
  | `aadhar_file_path` | File | Yes | Aadhaar Card Document File |
  | `pan_file_path` | File | No | PAN Card Document File |
  | `referral_code` | String | No | Referral code |

---

<a name="provider-profile--documents"></a>
### 4.2 Provider Profile & Document Management

#### Update Provider Profile
- **Endpoint:** `POST /provider/update-profile`
- **Parameters (Multipart):** Same fields as registration for updating profile information and documents.

#### Document Verification Vault
- `GET /provider/documents` — Fetch list of uploaded verification documents and approval status (`pending`, `verified`, `rejected`).
- `POST /provider/document-addUpdate` — Upload or update verification document.
  - **Parameters (Multipart):** `id` (optional), `service_provider_id`, `document_type` (`aadhar`, `pan`, `nursing_degree`, `experience_certificate`), `document_name`, `document_number`, `issue_date`, `expiry_date`, `document_file` (File).
- `POST /provider/document-delete/{id}` — Delete uploaded document.

---

<a name="provider-duty--availability-management"></a>
### 4.3 Duty & Availability Management

- **Update Live GPS Location:** `POST /provider/update-current-location`
  - Parameters (JSON): `latitude`, `longitude`.
- **Toggle Online/Duty Status:** `POST /provider/update-is-available`
  - Parameters (JSON): `is_available` (`"1"` for Duty On, `"0"` for Offline).
- **Get Weekly Working Schedule:** `GET /provider/get-weekly-availability`
- **Update Weekly Schedule:** `POST /provider/update-weekly-availability`
  - Parameters (JSON): Array of week days with `start_time`, `end_time`, `is_active`.
- **Manage Service Categories:**
  - `GET /provider/services` — View assigned categories.
  - `POST /provider/service-save` — Select categories (`service_category_id`).
  - `POST /provider/service-delete/{id}` — Remove category.

---

<a name="provider-service-requests--bookings-flow"></a>
### 4.4 Service Requests / Bookings Flow

#### 1. Fetch Duty Requests
- **Endpoint:** `GET /provider/service-requests`
- **Query Parameters:** `status` (`pending`, `accepted`, `in_progress`, `completed`, `cancelled`), `page`.

#### 2. Get Request Details
- **Endpoint:** `GET /provider/service-requests/details`
- **Query Parameters:** `service_request_id` (int).

#### 3. Accept or Reject Request
- **Endpoint:** `POST /provider/service-requests/respond`
- **Parameters (Multipart):**
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `service_request_id` | String | Yes | Service Request ID |
  | `action` | String | Yes | `accepted` or `rejected` |
  | `booking_unit_ids[i]` | Array | No | Specific sub-block session IDs accepted |

#### 4. Start Booking / Duty Session
- **Endpoint:** `POST /provider/service-requests/start-booking`
- **Parameters (Multipart):** `service_request_id` / `booking_unit_id`, `start_otp` (if required).

#### 5. Send Completion OTP to Patient
- **Endpoint:** `POST /provider/service-requests/send-otp`
- **Parameters (Multipart):** `booking_id`, `mobile_number`.

#### 6. Complete Booking / Duty Session
- **Endpoint:** `POST /provider/service-requests/complete`
- **Parameters (Multipart):** `booking_id`, `otp`.

#### 7. Provider Session Cancellation
- `GET /provider/service-requests/cancellation-preview` — Preview cancellation terms.
- `POST /provider/service-requests/cancel` — Cancel accepted session (`service_request_id`, `reason`).

---

<a name="provider-earnings--wallet-withdrawals"></a>
### 4.5 Provider Earnings & Wallet Withdrawals

- **Dashboard Summary:** `GET /provider/dashboard` — Returns active jobs count, total completed bookings, aggregate ratings, wallet balance.
- **Earnings Breakdown:** `GET /provider/earnings`
  - Query Parameters: `filter` (`today`, `this_week`, `this_month`, `custom`), `start_date`, `end_date`.
- **Wallet Overview:** `GET /provider/wallet` — Balance and payout summary.
- **Wallet Transactions:** `GET /provider/wallet/transactions` — Detailed ledger statement.
- **Withdrawal Requests:**
  - `GET /provider/wallet/withdrawals` — List request history.
  - `POST /provider/wallet/withdrawals/request` — Submit withdrawal (`amount`).
  - `POST /provider/wallet/withdrawals/{id}/cancel` — Cancel pending payout request.

---

<a name="provider-bank-details"></a>
### 4.6 Bank Details

- **Get Bank Detail:** `GET /provider/bank-detail`
- **Save Bank Detail:** `POST /provider/save-bank-detail`
  - **Parameters (Multipart):**
    | Parameter | Type | Required | Description |
    |---|---|---|---|
    | `bank_detail_id` | String | No | Bank record ID (for editing) |
    | `account_holder_name` | String | Yes | Name as per Bank Account |
    | `account_number` | String | Yes | Bank Account Number |
    | `ifsc_code` | String | Yes | 11-character IFSC Code |
    | `bank_name` | String | Yes | Bank Name (e.g. HDFC Bank, SBI) |
    | `branch_name` | String | Yes | Branch Name |
    | `account_type` | String | Yes | `savings` or `current` |
    | `is_primary` | String | Yes | `"1"` (Primary Account) or `"0"` |

---

<a name="provider-registration-fee-payment"></a>
### 4.7 Registration Fee Payment

- **Initiate Registration Payment:** `POST /provider/registration-fee-payment-initiate`
  - Parameters (Multipart): `registration_fee`, `amount`.
  - Response:
    ```json
    {
      "status": true,
      "data": {
        "razorpay_order_id": "order_P1X8zK9L0abc",
        "amount": 50000,
        "currency": "INR",
        "razorpay_key": "rzp_live_xxxxxxxx",
        "temp_order_id": 9821
      }
    }
    ```
- **Verify Payment:** `POST /auth/payments/verify`
  - Parameters: `amount`, `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature`.

---

## 5. Error Handling & Status Codes

The API returns standard HTTP status codes along with JSON error payloads.

| Status Code | Reason | Description |
|---|---|---|
| `200 OK` | Success | Request succeeded |
| `201 Created` | Created | Resource successfully created |
| `400 Bad Request` | Client Error | Invalid syntax or missing required parameters |
| `401 Unauthorized` | Unauthenticated | Missing or invalid Bearer Token / Expired session |
| `403 Forbidden` | Access Denied | User does not have authorization role for endpoint |
| `404 Not Found` | Not Found | Resource or endpoint does not exist |
| `422 Unprocessable Entity` | Validation Error | Form parameter validation failed |
| `500 Server Error` | Internal Failure | Unexpected backend error |

### Standard Validation Error Response (`422`)
```json
{
  "status": false,
  "message": "The given data was invalid.",
  "errors": {
    "mobile_number": [
      "The mobile number must be 10 digits."
    ],
    "email": [
      "The email has already been taken."
    ]
  }
}
```
