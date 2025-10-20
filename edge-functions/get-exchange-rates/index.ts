import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Handle CORS for iOS requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Across-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { currency } = await req.json()
    
    if (!currency) {
      return new Response(
        JSON.stringify({ error: "Currency code required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }
    
    // Fetch from NBU API (National Bank of Ukraine)
    const response = await fetch(
      `https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?valcode=${currency}&json`
    )
    
    if (!response.ok) {
      throw new Error(`NBU API error: ${response.status}`)
    }
    
    const data = await response.json()
    
    if (data.length === 0) {
      return new Response(
        JSON.stringify({ error: "Currency not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      )
    }
    
    return new Response(
      JSON.stringify({ 
        currency: currency,
        rate: data[0].rate,
        timestamp: new Date().toISOString()
      }),
      { 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        error: error.message || "Internal server error"
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})
