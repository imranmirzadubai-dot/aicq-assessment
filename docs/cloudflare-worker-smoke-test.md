# Smoke test

After deployment, check:

https://aicq-foundation-api.imranmirzadubai.workers.dev/health

Expected:
`"version":"1.9"`

Then from the AICQ participant page console:

fetch("https://aicq-foundation-api.imranmirzadubai.workers.dev/v1/attempts", {
  method: "POST",
  headers: {"Content-Type":"application/json"},
  body: JSON.stringify({
    assessment_code: "AICQ-P1",
    form_code: "AICQ-P1-F01",
    form_version: "1.0",
    participant_name: "AICQ FINAL TEST",
    participant_age: 35,
    participant_occupation: "Test",
    participant_experience: 5
  })
}).then(async r => {
  console.log("HTTP STATUS:", r.status);
  console.log("RESPONSE:", await r.text());
});
