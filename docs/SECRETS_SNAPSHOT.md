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
- JSON key (added to GitHub secret `GCP_SA_KEY` on 2025-11-07; rotate again once CI is validated):

```
{
  "type": "service_account",
  "project_id": "mereka-lms",
  "private_key_id": "12839a80a0cfebffdad6b9d282ca48c396955891",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCn5kWv0fCwgS2l\nfT9safFS05owXTHj47lmLe/0yMKq/dT6kK6mu5hIKcUqdqqKNR+tzrtXMlIQWApy\nJXszeoDOb2yqEkSmUnPwwMOekDei89WJFadIYtPUcAksYpUnytN3W83ImwW8D/Gx\nSQqbZfsKvUiWyAoYoh9SPERWZhRH2RQNCjCsmEwfpRTPeT1aOYS/HDaBUNijZYF+\nKjrIaz9JLfB6u7tAn0sbWEGs7ei/C/g7Ctt8nDuRamnKD4CIEl1wy/2PpzhU1LkF\nms+jQNXqirHt+Z7tv/9jeGkKvCjV/FRLHhSCvfRgSVA3Yx+xv6bXzKkgqIcg9dTu\npyxm4KeNAgMBAAECggEALtOUP/MHc9KzTmJeG/h4K6eEa1Syo2JRxOOu9tA/Kr1c\ndv1/GFVdpVKxAKTT73Pdf/YWXb1VEeXcE/XMJJFX9zswTUaHCvQYDd9VL5X9Tl8/\nANqfKxsVBTyx8kUUYGK7E6DxBa/mq4qu18kNQkXw/A/KfPMRjck5fw/75zTVFyxK\nPD+3+5dZ9YlUXK6RrUTGBl58CJsNaUBvhBjqasy9Vse0wqZZLSB4eHaRonZh1j8+\nGRhGA4I8CDD0jDLcWsd8O65tbmTgzgqTbmUI4o7Fss+LiErzkjK6nXnPKi2nkZa2\n7VIf22d47Xwnbztq6HQkgpzn+etCvnmQ7qTze3DXaQKBgQDQDEDPMnOd20ukCxVS\nNLH/VBKtXlKTM5ofo+qZpzPN95TwQ5evmxmLURzgjxfe1UofJh6XSZahlivakigD\niT28cOHAPM3mfmkqxM82WTapZYJLVRlHugl1NXcrTtJQw/BMbWmWwIksh0K1ZuLg\nIL3TjWLxZyhkdskkH7ynzWhdFwKBgQDOmRZo90gJtpBC094oNvJIun/ochVaTR4z\n0lfaOMlMWZD+8yspteoQrM4TbOKcoVTgjmB/+sVK9EFvL0jvAjG525o44uGfVVmx\nB7qMt7X3f8b12hTArawbpGektKWcXCJgfrPGQoJ7FPvkL53+sV/DdBMf+RkZQah7\nseXBEk7u+wKBgDCRG7QCwBCyt8a0u6Z0HLVRKAcGxNoOKsWGG2cBLEvBpygrb0aU\nO3NVXRti7Bydx+7blDqW+C4Cg3xDsEmbCSlrZJfe2eYbzmsohILYcrU6uB7j38Hp\nwPl2oLogbWJjSz5cMFD740nczYrRWNcfbZDsKZPXFAvX2v6u1fiKL/nDAoGBALXC\npZ6vf6dcAMtqjtcekEZAHmwognSxyFKbSkNpFmCfpBtJYL4Pl+AXyC3669wVbBEr\n8eZmf9ET18Wz+hyc95amh6ZopUuC0agYPp2yutsGhcqilQN3SCYBnFWhwNoxjOUM\nU6mnthgHPB1jb0M2ViQlKPZGNzirNUmuF46nRt6lAoGBAJvURe33aQapNAhBWN0/\nnw8BOObf+l6F+N+ebHp2tPQ5t/CGa8dBwTj3gMFwc9H5riQ95fW8jfVKjKQM7ZH/\npXoEOgHGacsWbJ2HxA7GMW3YFTLEJabUCb6o9OLSF3uefKGWcmoBB1kwxWC2Hih7\nQJNMTPh/SMYJDdNEN3lce7Vz\n-----END PRIVATE KEY-----\n",
  "client_email": "cloud-sql-backup@mereka-lms.iam.gserviceaccount.com",
  "client_id": "115360769815101767052",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/cloud-sql-backup%40mereka-lms.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
```

> Previous key `dfc68a907f1c26c94720b8d4684a415d24ccde4b` was deleted immediately after publishing this version. Always rotate once GitHub Actions is validated.
