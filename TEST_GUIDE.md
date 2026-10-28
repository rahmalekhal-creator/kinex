# Clinic-Only Registration: End-to-End Test Guide

## Setup Checklist
- ✅ PHP files synchronized to `C:\wamp64\www\reed\`
- ✅ Flutter UI updated with clinic-only messaging
- ✅ Backend security checks hardened
- ✅ Database supports clinic approval workflow

---

## Full Test Workflow

### Phase 1: Clinic Registration
1. **Open Flutter app** → Click **"Create clinic account"** (on Loginscreen)
2. **Fill clinic form**:
   - Clinic name: `Test Clinic`
   - Email: `clinic1@example.com`
   - Password: `password123`
   - Address: `123 Main St`
   - Phone: `555-1234`
   - Upload justification file (PDF/JPG)
3. **Verify**:
   - Response: _"Demande envoyée"_ (Request sent)
   - App redirects to Login screen
   - Clinic account created with `is_active=0` in database

### Phase 2: Admin Approval
1. **Open Flutter app** → Login as **admin** account
   - Email: (leave blank or use seeded admin account)
   - Password: (seeded admin password)
2. **Admin Dashboard** → "Pending Clinics" tab
3. **Click "Approve"** on `Test Clinic`
4. **Verify**:
   - Clinic account `is_active` changes to `1`
   - Response: _"Clinic approved"_

### Phase 3: Clinic Login (Before Approval)
1. **Open Flutter app** → Click **"Login"** (Loginscreen)
2. **Enter clinic credentials**:
   - Email: `clinic1@example.com`
   - Password: `password123`
3. **Verify (before approval)**:
   - Error dialog: _"Waiting for approval"_
   - Clinic is NOT routed to dashboard

### Phase 4: Clinic Login (After Approval)
1. **Repeat Phase 3** with same credentials
2. **Verify (after approval)**:
   - Success dialog: _"Login Successful!"_
   - Routed to `ClinicDashboardPage`

### Phase 5: Create Patient
1. **Inside Clinic Dashboard** → Select **"Members"** tab
2. **Fill member form**:
   - Role: **Patient**
   - Full name: `John Doe`
   - Email: `patient1@example.com`
   - Password: `patient123`
   - Phone: `555-5678`
   - Birth date: `1990-01-15` (or leave blank)
   - Physiotherapist: (select one if available, or "No assignment")
3. **Click "Create member"**
4. **Verify**:
   - Success response: _"Patient account created successfully"_
   - Patient appears in "Overview" → "Assigned patients"
   - Patient count increments
   - New `patient` account created with `is_active=1`

### Phase 6: Create Physiotherapist
1. **Inside Clinic Dashboard** → Select **"Members"** tab
2. **Fill member form**:
   - Role: **Physiotherapist**
   - Full name: `Dr. Jane Smith`
   - Email: `physio1@example.com`
   - Password: `physio123`
   - Phone: `555-7890`
   - Specialization: `Orthopedic`
3. **Click "Create member"**
4. **Verify**:
   - Success response: _"Physiotherapist account created successfully"_
   - Therapist appears in therapist dropdown for new patients
   - Therapist count increments
   - New `therapist` account created with `is_active=1`

### Phase 7: Test Approval Gate
1. **Create a second clinic** (repeat Phase 1 with different email)
2. **Try to access Dashboard WITHOUT approval**:
   - App requests dashboard data
   - Backend responds: _"Clinic account must be approved before using this feature"_
   - Dashboard fails to load

### Phase 8: Test Member Creation Gate
1. **Create clinic** and **register member BEFORE admin approval**
2. **Try to create patient/therapist WITHOUT clinic approval**:
   - Backend responds: _"Clinic account must be approved before using this feature"_
   - Member creation fails

---

## Expected Database State After Tests

### Accounts Table
```
id | email                  | role          | is_active
1  | admin@example.com      | admin         | 1
2  | clinic1@example.com    | clinic        | 1  (approved)
3  | patient1@example.com   | patient       | 1
4  | physio1@example.com    | therapist     | 1
5  | clinic2@example.com    | clinic        | 0  (pending approval)
```

### Clinic Table
```
id | account_id | name         | justif
1  | 2          | Test Clinic  | uploads/justif/...
2  | 5          | Test Clinic2 | uploads/justif/...
```

### Patient Table
```
id | account_id | clinic_id | therapist_id | name       | is_active
1  | 3          | 1         | 1            | John Doe   | 1
```

### Physiotherapist Table
```
id | account_id | clinic_id | name           | specialization | is_active
1  | 4          | 1         | Dr. Jane Smith | Orthopedic     | 1
```

---

## Error Scenarios to Test

### ❌ Scenario: Clinic Not Yet Approved
**Action**: Login with unapproved clinic  
**Expected**: _"Waiting for approval"_  
**Backend check**: Line 61 in `login.php`

### ❌ Scenario: Try Member Creation as Unapproved Clinic
**Action**: Try creating patient/therapist without approval  
**Expected**: _"Clinic account must be approved before using this feature"_  
**Backend check**: Line 28 in `clinic_register_member.php` (calls `require_active_clinic_account()`)

### ❌ Scenario: Dashboard Access as Unapproved Clinic
**Action**: Try loading clinic dashboard without approval  
**Expected**: _"Clinic account must be approved before using this feature"_  
**Backend check**: Line 9 in `get_clinic_dashboard.php` (calls `require_active_clinic_account()`)

### ❌ Scenario: Duplicate Email on Member Registration
**Action**: Create patient with email already in accounts table  
**Expected**: _"Email already exists"_  
**Backend check**: Line 42 in `clinic_register_member.php`

---

## Success Criteria Checklist

- [ ] Clinics **cannot** be registered as patients or physiotherapists
- [ ] Patients/physiotherapists **cannot** be registered from login screen
- [ ] Clinic registration requires admin approval
- [ ] Unapproved clinics see **"Waiting for approval"** message
- [ ] Approved clinics can access dashboard
- [ ] Dashboard auto-uses logged-in clinic account (no selector)
- [ ] Member creation only works for **approved clinics**
- [ ] Patients assigned to clinic automatically
- [ ] Therapists assigned to clinic automatically
- [ ] Therapist list limited to clinic's own therapists
- [ ] All endpoints check `is_active = 1` for clinic accounts

---

## API Endpoints Reference

### Public Endpoints
- `POST signup.php` → Clinic registration
- `POST login.php` → Universal login
- `POST send_physio_message.php` → Messaging

### Clinic-Protected Endpoints
- `GET get_clinic_dashboard.php?account_id=X` → requires `is_active=1`
- `POST clinic_register_member.php` → requires `is_active=1`
- `POST clinic_update_profile.php` → requires `is_active=1`
- `POST create_subscription.php` → requires `is_active=1`

### Admin-Protected Endpoints
- `GET get_admin_dashboard.php?account_id=X` → requires `role=admin`
- `POST admin_set_clinic_status.php` → requires `role=admin`
- `POST admin_update_account.php` → requires `role=admin`
- `POST admin_update_clinic.php` → requires `role=admin`

---

## Notes
- Justification files stored in: `C:\wamp64\www\reed\uploads\justif\`
- All passwords hashed using PHP's `password_hash()`
- Session persistence managed by Flutter `riverpod` providers
- Backend applies date checks for subscriptions (premium gating)

