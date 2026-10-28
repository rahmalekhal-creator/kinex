# Feature/Actor Architecture

This folder organizes the app by actor/feature while keeping backward compatibility.

## Actors
- `auth/`: onboarding, login, signup, auth-related models
- `admin/`: admin pages and admin-focused models
- `clinic/`: clinic pages and clinic-focused models
- `patient/`: patient pages and patient-focused models
- `therapist/`: physiotherapist pages and therapist-focused models

## Migration approach
- Current files under `lib/pages` and `lib/models` remain the source of truth.
- New actor files currently re-export existing libraries to avoid breaking imports.
- New development should import from `lib/features/<actor>/<actor>.dart`.

## Next step
Move implementations from `lib/pages` and `lib/models` into these actor folders progressively,
then replace re-exports with real files.

