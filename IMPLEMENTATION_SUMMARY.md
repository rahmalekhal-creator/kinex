# SignupScreen Implementation with Models

## Summary of Changes

### 1. **SignupScreen.dart** - Now uses Model Classes
- **Imports Added**:
  - `Patient` model from `models/Patient.dart`
  - `Physiotherapist` model from `models/Physiotherapist.dart`

- **Role-Based Forms**:
  - User selects role: "Patient" or "Physiotherapist"
  - Form fields dynamically display based on selection
  
- **Patient Signup**:
  - Creates `Patient` model with form data
  - Extracts data from model to send to backend
  - Fields: name, phone, birth_date, clinic_id

- **Physiotherapist Signup**:
  - Creates `Physiotherapist` model with form data
  - Extracts data from model to send to backend
  - Fields: name, specialization, phone, clinic_id

### 2. **Data Flow**

```
SignupScreen Form
    ↓
User selects role & fills form
    ↓
_submitForm() validates form
    ↓
Creates Model instance (Patient or Physiotherapist)
    ↓
Extracts model data into Map<String, dynamic>
    ↓
Calls db.signup(data)
    ↓
DB_API sends to backend (signup.php)
    ↓
signup.php creates user account and role-specific record
    ↓
Returns response to app
    ↓
Navigate to LoginScreen on success
```

### 3. **Data Sent to Backend**

**Common fields (both roles)**:
```
{
  "role": "patient" or "physiotherapist",
  "email": "user@example.com",
  "password": "password123",
}
```

**Patient-specific**:
```
{
  "name": "John Doe",
  "phone": "0123456789",
  "birth_date": "1990-01-15",
  "clinic_id": 1,
}
```

**Physiotherapist-specific**:
```
{
  "name": "Jane Doe",
  "specialization": "Sports Injury",
  "phone": "0123456789",
  "clinic_id": 1,
}
```

### 4. **Backend Integration (signup.php)**

The PHP file in WAMP:
- Located at: `c:\wamp64\www\reed\signup.php`
- Validates all inputs
- Creates user account in `user` table
- Creates role-specific record in `patient` or `physiotherapist` table
- Returns appropriate JSON response

### 5. **Model Usage Benefits**

✅ **Type Safety**: Models provide structure and validation
✅ **Consistency**: Data follows the same format as API responses
✅ **Maintainability**: Changes to models propagate throughout app
✅ **Future Extensibility**: Easy to add new fields to models
✅ **Data Integrity**: All conversions handled by model's toJson/fromJson

## Testing

1. **Patient Signup Test**:
   - Select "Patient" role
   - Fill all fields including DOB
   - Submit
   - Verify user created in `user` table with role='patient'
   - Verify record created in `patient` table

2. **Physiotherapist Signup Test**:
   - Select "Physiotherapist" role
   - Fill all fields including specialization
   - Submit
   - Verify user created in `user` table with role='physiotherapist'
   - Verify record created in `physiotherapist` table (if exists)

## Files Modified

- ✅ `lib/pages/SignupScreen.dart` - Role-based form with model usage
- ✅ `lib/DB_API.dart` - Updated signup method
- ✅ `c:\wamp64\www\reed\signup.php` - Backend signup handler

## Next Steps

1. Verify the `physiotherapist` table exists in your database
2. Test both patient and physiotherapist signup flows
3. Ensure clinic selection is working properly
4. Consider fetching clinic list dynamically from backend instead of hardcoding

