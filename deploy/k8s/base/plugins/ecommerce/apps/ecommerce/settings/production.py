from ..production import *

import json
import os

SECRET_KEY = "39RbimInoqcQHbn0xLvU"
ALLOWED_HOSTS = [
    "ecommerce.localhost",
    "ecommerce",
]
PLATFORM_NAME = "My Open edX"
PROTOCOL = "http"

CORS_ALLOW_CREDENTIALS = True

OSCAR_DEFAULT_CURRENCY = "USD"

EDX_API_KEY = "6Lnq77PWhG8kqVppsvkq"

JWT_AUTH["JWT_ISSUER"] = "http://localhost/oauth2"
JWT_AUTH["JWT_AUDIENCE"] = "openedx"
JWT_AUTH["JWT_SECRET_KEY"] = "UeCMQQglnc0O68rTJQezNNSt"
JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps(
    {
        "keys": [
            {
                "kid": "openedx",
                "kty": "RSA",
                "e": "AQAB",
                "n": "nyKlrWYvtK405Rrvzb9zbtdyUvKgMyhySpiRNIvkhi8AqbmhyGYobRU6oOtjWdNTPy4Lfbx1TfB4EPo1BT2HIVenhm6TtTNwiKubJELwSOZSHNgq92GPzsXO868e86GWSzI9sLu4IXs1Egz81Sp5669YYmxDostWYZgyljXt7wdjOGbl-HQUgOppQMY1zH263A2pkTZ65kunEBzZyM_RtVb6yBi4hcSmU7q6jFbBniGjxY236hp6J9kRggsM-rHIuV0qHLlkBi23wVE0r866g6TwUcTqnHRn717RN1ZfHf76A3GN3UvgOgT4mEwaLoTijL8hzhLie1pgqCb7P2L3Yw",
            }
        ]
    }
)
JWT_AUTH["JWT_ISSUERS"] = [
    {
        "ISSUER": "http://localhost/oauth2",
        "AUDIENCE": "openedx",
        "SECRET_KEY": "UeCMQQglnc0O68rTJQezNNSt"
    }
]

SOCIAL_AUTH_REDIRECT_IS_HTTPS = False
SOCIAL_AUTH_EDX_OAUTH2_ISSUER = "http://localhost"
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = "http://lms:8000"

BACKEND_SERVICE_EDX_OAUTH2_SECRET = "yU1JIVuY"
BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = "http://lms:8000/oauth2"

EDX_DRF_EXTENSIONS = {
    'OAUTH2_USER_INFO_URL': 'http://localhost/oauth2/user_info',
}

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": "ecommerce",
        "USER": "ecommerce",
        "PASSWORD": "gHS5cTHo",
        "HOST": "mysql",
        "PORT": "3306",
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "smtp"
EMAIL_PORT = "8025"
EMAIL_HOST_USER = ""
EMAIL_HOST_PASSWORD = ""
EMAIL_USE_TLS = False

ENTERPRISE_SERVICE_URL = 'http://localhost/enterprise/'
ENTERPRISE_API_URL = urljoin(ENTERPRISE_SERVICE_URL, 'api/v1/')

# Get rid of local logger
LOGGING["handlers"].pop("local")
for logger in LOGGING["loggers"].values():
    logger["handlers"].remove("local")

# Load payment processors
with open(
    os.path.join(os.path.dirname(__file__), "paymentprocessors.json"),
    encoding="utf8"
) as payment_processors_file:
    common_payment_processor_config = json.load(payment_processors_file)

# Fix cybersource-rest configuration
if "cybersource" in common_payment_processor_config and "cybersource-rest" not in common_payment_processor_config:
    common_payment_processor_config["cybersource-rest"] = common_payment_processor_config["cybersource"]
PAYMENT_PROCESSOR_CONFIG = {
    "openedx": common_payment_processor_config,
    "dev": common_payment_processor_config,
}
# Dummy config is required to bypass a KeyError
PAYMENT_PROCESSOR_CONFIG["edx"] = {
    "stripe": {
        "secret_key": "",
        "webhook_endpoint_secret": "",
    }
}
PAYMENT_PROCESSORS = list(PAYMENT_PROCESSORS) + []





CORS_ORIGIN_WHITELIST = list(CORS_ORIGIN_WHITELIST) + [
    "http://apps.localhost",
]
CSRF_TRUSTED_ORIGINS = ["apps.localhost"]

SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = "http://localhost"

BACKEND_SERVICE_EDX_OAUTH2_KEY = "ecommerce"

