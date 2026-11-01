// Reads the newest sign-in code the Auth emulator "sent" (it logs codes instead of texting
// them) and hands it to the flow as output.smsCode. Runs on the Mac, so 127.0.0.1 is the
// emulator's own address even when the app reaches it as 10.0.2.2.
const response = http.get(
  'http://127.0.0.1:9099/emulator/v1/projects/ronda-uy/verificationCodes',
);
const codes = json(response.body).verificationCodes || [];
if (codes.length === 0) {
  throw new Error('The Auth emulator has no verification code yet');
}
output.smsCode = codes[codes.length - 1].code;
