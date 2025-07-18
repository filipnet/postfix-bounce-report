# Sender Marking in Postfix Bounce Reports

This document explains the logic behind marking bounced emails as **resent** or **spoofing** in the postfix bounce report script, and how related configuration and helper scripts work together.

## Purpose of Markings

- **Resent**: Marks emails from senders that you have previously sent mail to (i.e., known recipients), but where the sending domain is **outside** your trusted domain list.  
  These addresses are potentially trustworthy due to prior communication, but replies from external domains can cause false positives in bounce detection.

- **Spoofing**: Marks emails where the sender claims to be from one of your trusted internal domains but is **not recognized** as a known sender.  
  This signals possible spoofing attempts aiming to impersonate legitimate internal users or domains.

## Configuration Flags

- `RECIPIENTS_CHECK`  
  Enables checking if the sender is a known recipient based on an authenticated senders list. Necessary for correct **resent** marking.

- `SPOOFING_CHECK`  
  Enables detection of spoofing attempts by marking emails with sender domains in your trusted list, regardless of sender recognition.

- `DOMAINS`  
  A pipe-separated list of trusted internal email domains used to differentiate internal vs external domains.

## Known Senders List and Its Generation

The **known senders list** (`RECIPIENTS_LIST`) is a crucial data source used to identify trusted senders for the **resent** marking. This list is **continuously built and updated** by a separate helper script called `postfix-build-submission-recipients.sh`.

### Role of the Helper Script

- It parses the postfix mail logs for authenticated outbound emails (submission via SASL).
- Extracts sender addresses who have legitimately sent mail through your system.
- Normalizes and deduplicates these addresses.
- Updates the `RECIPIENTS_LIST` file.

Maintaining this list is essential because without it, the bounce report script cannot reliably distinguish known senders from unknown ones, reducing the accuracy of the **resent** marking.

## Marking Logic

- If the sender is known (a recipient you have previously sent mail to) and their domain is **not** in the trusted domains list → mark as **resent**.  
  This indicates mail coming from external domains tied to previously contacted addresses and can sometimes produce false positives.

- If the sender’s domain **is** in the trusted domains list → mark as **spoofing** (regardless of known status).  
  This helps detect impersonation attempts using your internal domains.

## Summary

To use the marking effectively:

- Enable `RECIPIENTS_CHECK` for known recipient verification.  
- Enable `SPOOFING_CHECK` to detect spoofing attempts.  
- Keep the known senders list updated regularly with the helper script `postfix-build-submission-recipients.sh`.  
- Define your trusted domains clearly in the configuration.

Together, these mechanisms help you monitor and flag suspicious email activity in postfix bounce reports, while being aware that some resent markings may be false positives due to legitimate external replies.
