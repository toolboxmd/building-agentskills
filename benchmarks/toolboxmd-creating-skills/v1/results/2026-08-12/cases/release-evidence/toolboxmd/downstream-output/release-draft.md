## Release notes

- Harborline adds resumable uploads for files sent through the desktop client. [evidence: COMMIT-HL-412]
- In acceptance testing, all 30 interrupted uploads of synthetic 2 GB fixtures on macOS 15.4 over a controlled local network resumed and matched their source SHA-256 values. [evidence: TEST-HL-63]
- The desktop client status panel now displays the last verified checkpoint before resuming an upload. [evidence: COMMIT-HL-419]

## Withheld or unsupported claims

- Claim: Harborline uploads are unbreakable on every device and network.
  Reason: COMMIT-HL-412 is limited to desktop client uploads, TEST-HL-63 covers only 30 synthetic 2 GB fixtures on macOS 15.4 over a controlled local network, and mobile resumable uploads remain unshipped in PLAN-HL-90.
- Claim: Harborline uploads never lose data.
  Reason: REJECT-HL-14 explicitly rejects this absolute claim because it exceeds the controlled acceptance scope; TEST-HL-63 establishes matching source SHA-256 values only for its 30 tested interrupted uploads.
- Claim: Uploads resume 60 percent faster.
  Reason: OBS-HL-07 is an unverified teammate estimate, not a measured or passed performance result.
- Claim: Mobile users can continue an upload on desktop.
  Reason: Mobile resumable uploads and cross-device continuation are unshipped plans in PLAN-HL-90, with no shipped implementation or passed acceptance evidence.
