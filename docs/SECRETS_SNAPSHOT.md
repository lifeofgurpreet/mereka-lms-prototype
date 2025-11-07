# Temporary Secrets Snapshot

> **Rotate ASAP.** These values are for initial bring-up only. Replace them in Google Secret Manager (or equivalent) before go-live.

## Application Secrets

| Key | Value |
|-----|-------|
| Django `SECRET_KEY` | `Rf6FngsKfgb1FpvXlDkhs2mpMnSPwfQ5I7fbHCRaEEJmWjmzkv` |
| JWT RSA Private Key | ```
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAq9RmBLUtEgYRj+NuG5w3arg4lLHKSNVd06A4BDRWyChWmHId
smRpQYOvKDRg4avnxYw2jTjkAgX6KmPJp6R71h5agp+Em5YNMAZpvn1NLhfMlFdW
DYttGtwX/+bF8jwXaFCKjyUyL5SXzEuO4i8L9Zx5VuQVoFcJB7JuxVzSsDGkcfU/
zltMYYUbEEyssUz5pzAMyiuw3974W/9+h//HO8uRlpsyr8R/rEpbeTUOdJ1WpSCY
11JHkiKAKrlUNSLdSmigiUuuv7fJh0IKmM9HoelfUBYd7OIgX5ef/ym73prdy760
GB+GV7gldErVyoI1oW/5Wl1uh2iEJ8HbWjgWAQIDAQABAoIBAA118CACSWuWCh4p
hOCo1jaIA/ayDtSx0k3XyUubBglcD5yVo/nrn8tAE6Kkp8pF+zwghc1+XW5DJZvY
gV2epwzZB+IfuPWvRY0zk2kWy8sGlkIwrU8WUw+9miuz2mHljzfex1v7X/kWPOYG
LUVOxjMRdPf3mjIbX1u5ALB5Ww/uUrUCin1RTJay+qr5cHksLkjGd6LXvkSrjpOJ
4XhP9mVkr61VNUiWvWtvedXinqtJg+jscfQd9xxI/bfYOXMl5+NR9bduq4ZHZlbT
ggo/XKFsJACIqAHEUM9O/7EtXxdpTPkK9wJzn1vJmQCY4LuGwcw0/ejFelVfUEQH
CNTugIECgYEA3y+CwY84GcNtnpbvx1VkZwQvovaXpkOw3Kb2mlmDFJQTlANIpt4g
Gd8RZ1ivDuhu7fAmrDqZRPCaSkJez0KGdjGL6GHkjDoc4vQKKUddf9NTjBJexP9d
ctykivmsYtltWWdinTrEuH8ZsBrx4wed+ZeVjHSv3V0O/2BtF8cb3UkCgYEAxRfm
s08BMgTuoS0Q7mdYMdqDIqfUNd8BkVSs5Hic390eW2r9DJO12XoBV5ZHV4L/Ry06
zZGoMeOlbjY+VOkRuugaZhvQssetnlx5wbd+zQ2sl3iFwYVJgr9LSndsx5QqzixQ
6tB1V0zA7LZ/rQggs/Zd9bwfTQJgavtsdMqxCvkCgYAcItszF6EU7mQ1aAXWdVdw
/UAcJUY8+a+kQZA5KSuzPm+xazCPiNU3Lb3971oyYO8LJAlcEQ8dd8+bqP5W1qYo
5Fok86JiYzkdC3L0fUC2Sqfvsqkr4J2hS1ubAZrP42U7riLqe2wtbiiI4Py5iE5M
FuYNjPBW0dKAM2HNa5aBsQKBgQCa6kZy+c4+upG2Le349VHlHZOlUbUDAt4AlUWv
7v2fF/YcdOOhVxjAb51OcthweI6eK3bkzXAehogpMImdw/QjrPvS9ln7q+dTaexp
zwjjs7PM+vZnPZSiKCnNxkDCPjvHAh438tHIZJPfezKvlovd5+/CjrMrnIqcjDKb
OhYeQQKBgEi9vUea0RZhxX1rryZk5B31tsrg3LP3S9yo0yEDd26U3uIpszcY/n+M
/YlpSS5ZH8/glzIUOueoCyka1ZFV5CDb06yhjbX7TsgoRZfZ9TmmUXLddpidKseh
8Ph3ES+20ayXRBwjzg2b18atW+W3CrAsVMp+rJx1dcUxkQ6BA7oU
-----END RSA PRIVATE KEY-----
``` |
| JWT RSA Public Key | ```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq9RmBLUtEgYRj+NuG5w3
arg4lLHKSNVd06A4BDRWyChWmHIdsmRpQYOvKDRg4avnxYw2jTjkAgX6KmPJp6R7
1h5agp+Em5YNMAZpvn1NLhfMlFdWDYttGtwX/+bF8jwXaFCKjyUyL5SXzEuO4i8L
9Zx5VuQVoFcJB7JuxVzSsDGkcfU/zltMYYUbEEyssUz5pzAMyiuw3974W/9+h//H
O8uRlpsyr8R/rEpbeTUOdJ1WpSCY11JHkiKAKrlUNSLdSmigiUuuv7fJh0IKmM9H
oelfUBYd7OIgX5ef/ym73prdy760GB+GV7gldErVyoI1oW/5Wl1uh2iEJ8HbWjgW
AQIDAQAB
-----END PUBLIC KEY-----
``` |

## Database & Admin

| Purpose | Value |
|---------|-------|
| Cloud SQL root username | `root` |
| Cloud SQL root password | `Jgsn2RxQbP0p0CbNJ0wzhYZG` |
| Open edX MySQL password | `Vujnen2F7kn5Qdkf` |
| Discovery MySQL password | `9HL67vR90XEuzes0` |
| Notes MySQL password | `tp8BHjDHdHXTYzPy` |
| Open edX superuser email | `gurpreet@biji-biji.com` |
| Open edX superuser password | `NxO3mIpOqMiNJUKJwaYy` *(replace original `Cr3ativity`)* |
| MongoDB Atlas URI | `mongodb+srv://cs_comments_user:<password>@cluster0.xxxxx.mongodb.net/cs_comments_service?retryWrites=true&w=majority` *(placeholder—update once Atlas is provisioned)* |

## SMTP

- Provider: AWS SES (user `test-ses-smtp-user.20251106-131216-gtestingonly`)
- SMTP host: `email-smtp.ap-southeast-1.amazonaws.com`
- SMTP port: `587`
- SMTP username: `AKIAXHZNJFIAVN4UPP5H`
- SMTP password: `BP4CTi4XYWcrXNAhQdkmbY2kPAo0Fd6foVBgG9AB9loU`

---

Store these values in Google Secret Manager and reference them via Tutor configuration overrides. Rotate all credentials before production.

## Automation credentials

### Cloud SQL backup GitHub runner

- Service account: `cloud-sql-backup@mereka-lms.iam.gserviceaccount.com`
- Roles: `roles/cloudsql.admin`, `roles/storage.objectAdmin`
- JSON key (add to GitHub secret `GCP_SA_KEY` and rotate after first push):

```
{
  "type": "service_account",
  "project_id": "mereka-lms",
  "private_key_id": "dfc68a907f1c26c94720b8d4684a415d24ccde4b",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCZqSDO57V8XW9U\nSnrUSOPv7JO6Hf8Q86/8ViKDqjiLYm/pW8BY3XLyMsNiPR6IkxR1fiIsKtPB7ZX\nWYDJ7BpBAtpIsHLPoez/Ir6cJ3YDXUK6oSJqjg0Xg7AnG1G4aOyi8bTJepm3A9ww\nchmtVtKw+b0EkXk2tKjrHnLEO18eJQlvv63hxfgNwsCVdQYsPtkfdaaKpYxfakhR\nOLjzGn+todbm8B9yfX3kUvVJ2XpfONdTpXprP8eUwhOYVCM7mjSzFzLoDgBlHAu2\nyFgxarljfTk8NkNU3knOkPiolhXkYYlDUz5ZPggpu+cnxNmwy4nt2ADh6WcggJeL\n4aH5aPMJAgMBAAECggEAAff+fpn50xsS9SESwzwOBuLDr8fX7/2GlnpgxWnhcO/1\nI+y5a6t2V4Tg1T4eUoBF6PBHwAC0CaQFeDV2fKGj2TcDsuvGy6g0IB+C2is+D9KL\nXpFBLT5nyyKpWrMHWYLk7Dyr5OO//iwwwoXaztnd/zjKikfxjYiF2n7QgKxNjKMe\nW/zQATmpCzoi6QY8uGwUppKEuvMgIeU9itL/NZjpfvYGxqPewTNhfmWaJ2L4hKw0\nx79JPP1Huf0As3R9JBFrqQDh/WnCcBtt2zEtJHCzMsbVrZy8NVa64kPsiJSoVXPM\nexfnRvvsJMDhpj1hAVuOhYrcIkc1tZmdeYF/uEZyvwKBgQDJ//QtQd/wXxCzuydy\ncydnTPi3OUsn+NIWKxy0XJARTWScZMfksM11bKv+6xv2XOMOJqYy6wTH4w9pZvHl\n5ysJXMRxTg73xcRAenMF2M1C2YtM3ty3xucHnBOckxvlNONr3NzHUViFvE4FFD6R\np7S3NC/8lEoeq870jXOd/5uHPwKBgQDCvQnjSAZnnWtMNLmb4mpskz5JCntQ69GG\nGQkXjI9rkgzHxj/LR3aHosFDNBxDNWiHUpT1Z2T6/tmdThFEy43rONqzUAV21Ggb\nhHnFRchFCINMz3VYEWxbRd+WofpctjHHqDDzyaTsQTSDJ+vRt6dmVfu0h8Ri8m62\n22TW6MB7twKBgCMZsthaZgtiuYhBsS0WDXbJzT4pWoHrnrXzb913aCFZjW4PpRx8\nDHenFowJVqaMpXfEB4U5iW8iaX8rQEVu0e+iixAVPEyZtOxvWqVdcu1219nXsArP\nKT4NROskNOizNAF+M27/F57FhdkkF2s/9QsQqnX9XpPNzvx3x+tgiyoJAoGBAJp4\nOuynSDVOgDsNo6FMQyDm10Q25UR2GlglabndTDKGwk6BKj9D63iBmI2HO1fweH7G\n+dODdW1HVDTcJQSN9n/8NDaCJiNxLzeMqM7boJVpwETgVvNJtsrbrRSeXarG9sup\n1VK7w2+H9XCH7R4IcOfTEnrMKvJV3Y58jwuNyokXAoGBALvUxJmTNqI3jF1lPNCI\nLQkBHkI+s+Su/igBIh0c+oijn5yn050BdueIMSRTF2zI+31YYgDuMG1KH9dFuKii\n2jiHiwZxZd0ljPCLQjivk2Pvjb67UKsX7FAgqd4pS5hbro16lKKtOoJ5c7hecX2L\nLRQwayCUJEKVSvmWfga97klk\n-----END PRIVATE KEY-----\n",
  "client_email": "cloud-sql-backup@mereka-lms.iam.gserviceaccount.com",
  "client_id": "115360769815101767052",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/cloud-sql-backup%40mereka-lms.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
```
