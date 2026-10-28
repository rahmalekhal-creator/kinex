# KInex Clinic-Driven Registration Flow

## Overview
This document describes the clinic-only registration and member creation workflow. **Only clinics can register directly.** Patients and physiotherapists are created exclusively from the clinic dashboard.

---

## Flow Summary

### 1. Clinic Registration (Public / Login Screen)
- **Location**: `lib/pages/LoginScreen.dart` → "Create clinic account" button
- **Destination**: `lib/pages/SignupScreen.dart` (clinic-only form)
- **Backend**: `signup.php`
- **Process**:
  - Clinic fills in: name, email, password, address, phone, justification file
  - Justification file uploaded to `C:\wamp64\www\reed\uploads\justif\`
  - Account created with `role='clinic'` and `is_active=0`
  - Clinic awaits admin approval

---

### 2. Admin Approval
- **Admin Dashboard**: `lib/pages/AdminDashboardPage.dart`
- **Backend**: `admin_set_clinic_status.php`
- **Process**:
  - Admin views pending clinics
  - Admin clicks "Approve" → sets `account.is_active=1`
  - Clinic can now log in

---

### 3. Clinic Login
- **Login Screen**: `lib/pages/LoginScreen.dart`
- **Backend**: `login.php`
- **Process**:
  - Clinic enters email + password
  - System checks `account.is_active=1` (requires approval)
  - If waiting for approval: message **"Waiting for approval"** displayed
  - If approved: routes to `ClinicDashboardPage`

---

### 4. Clinic Member Creation (Dashboard Only)
- **Location**: `lib/pages/ClinicDashboardPage.dart` → "Members" tab
- **Backend**: `clinic_register_member.php`
- **Key Points**:
  - **Clinic account ID is automatically used** (no clinic selector shown)
  - Only available to **approved/active clinic accounts**
  - Creates either:
    - **Patient**: email, password, name, phone, birth_date, optional therapist assignment
    - **Physiotherapist**: email, password, name, phone, specialization
  - New accounts created with `is_active=1` immediately

---

## Backend Security Checks

### `api_common.php` - New Helper Function
```php
function require_active_clinic_account(mysqli $conn, $accountId)
{
    // Ensures account is:
    // 1. Role = 'clinic'
    // 2. is_active = 1
    // Returns clinic_id if valid, otherwise sends error response
}
```

### Protected Endpoints
The following endpoints now enforce `require_active_clinic_account()`:
- `clinic_register_member.php` - Create patient/therapist
- `get_clinic_dashboard.php` - Load clinic dashboard data
- `clinic_update_profile.php` - Edit clinic profile
- `create_subscription.php` - Create premium subscription

---

## Flutter UI Changes

### `LoginScreen.dart`
- **"New clinic?"** label changed to **"Clinic account only"**
- **"Register clinic"** button changed to **"Create clinic account"**
- Clear message: clinic registration only from this screen

### `SignupScreen.dart`
- **Title**: "Clinic registration"
- **Description**: "Create a clinic account only. After admin validation, you can access the dashboard and register your own patients and physiotherapists."
- **Footer note**: "Only clinics can register here. Patients and physiotherapists are created from the clinic dashboard using the logged-in clinic account."

### `ClinicDashboardPage.dart`
- **Members Tab**: Added clarification text
  - _"This uses your logged-in clinic account automatically. No clinic choice is shown."_
- Role dropdown: Patient / Physiotherapist only
- Therapist selection only for patients (optional)
- Auto-uses `widget.accountId` (clinic account ID)

---

## Database Changes
No schema changes required. Existing tables support:
- `account.role` ENUM includes `'clinic'`
- `account.is_active` (0 = pending approval, 1 = approved)
- `clinic.account_id` foreign key
- `patient.clinic_id` and `physiotherapist.clinic_id` references

---

## Testing Checklist

- [ ] Clinic registration form accepts clinic-only input (name, email, password, address, phone, justif file)
- [ ] Justification file uploaded to correct path
- [ ] Clinic account created with `is_active=0`
- [ ] Admin can view pending clinics
- [ ] Admin can approve clinic (sets `is_active=1`)
- [ ] Clinic login blocked until approval
- [ ] Clinic login successful after approval
- [ ] Clinic dashboard loads successfully
- [ ] Clinic can create patients with optional therapist assignment
- [ ] Clinic can create physiotherapists with specialization
- [ ] Patient/therapist accounts created with `is_active=1`
- [ ] Only approved clinics can create members (error if `is_active=0`)

---

## Synchronized Files to WAMP

All PHP files from `C:\Users\aseghiri\IdeaProjects\Reeducation\` have been copied to `C:\wamp64\www\reed\`:

- `api_common.php` ✓
- `clinic_register_member.php` ✓
- `clinic_update_profile.php` ✓
- `create_subscription.php` ✓
- `get_clinic_dashboard.php` ✓
- `login.php` ✓
- `signup.php` ✓
- `admin_set_clinic_status.php` ✓
- `get_admin_dashboard.php` ✓
- (+ all other existing endpoint files)

---

## Summary
✅ **Only clinics can register from the login page**  
✅ **Patients/physiotherapists created from clinic dashboard only**  
✅ **Clinic account ID auto-used (no clinic selector in dashboard)**  
✅ **Approval gating: clinics must be approved before dashboard access**  
✅ **All endpoints hardened with `require_active_clinic_account()`**

