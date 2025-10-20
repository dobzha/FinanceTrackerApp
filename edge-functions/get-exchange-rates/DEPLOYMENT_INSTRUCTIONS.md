
# Supabase Edge Function Deployment Instructions

## Function: get-exchange-rates

### 1. Deploy via Supabase CLI

Install Supabase CLI if not already installed:
```bash
npm install -g supabase
```

Login to Supabase:
```bash
supabase login
```

Link to your project:
```bash
supabase link --project-ref dslaholfbjctbzkgprio
```

Deploy the function:
```bash
cd /Users/igordobzhanskiy/Desktop/Finnik_iOS_app/edge-functions
supabase functions deploy get-exchange-rates
```

### 2. Test the Function

After deployment, test with curl:
```bash
curl -X POST https://dslaholfbjctbzkgprio.supabase.co/functions/v1/get-exchange-rates \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzbGFob2xmYmpjdGJ6a2dwcmlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3MjY5MTMsImV4cCI6MjA3NDMwMjkxM30.Zl8qZ1-t9pbLSptOvXNL0AglD3O8s729gLDuW_bsD2E" \
  -H "Content-Type: application/json" \
  -d '{"currency": "EUR"}'
```

Expected response:
```json
{
  "currency": "EUR",
  "rate": 0.92,
  "timestamp": "2025-01-20T..."
}
```

### 3. Verify in Supabase Dashboard

1. Go to https://supabase.com/dashboard/project/dslaholfbjctbzkgprio
2. Navigate to Edge Functions
3. Confirm `get-exchange-rates` is deployed and active

### 4. iOS App Usage

The iOS app will automatically use this function via CurrencyService.swift:
- URL: https://dslaholfbjctbzkgprio.supabase.co/functions/v1/get-exchange-rates
- Method: POST
- Headers: Authorization (Bearer token), Content-Type: application/json
- Body: {"currency": "EUR"}

### Troubleshooting

- If CORS errors: Check the function has proper CORS headers
- If 404: Verify function is deployed and URL is correct
- If auth errors: Verify anon key is correct in Config.swift
