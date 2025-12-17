import logging.config

from ecommerce_worker.configuration.logger import get_logger_config
from ..base import *

# For the record, we can't import settings from production module because a syslogger is
# configured there.

BROKER_URL = "redis://redis:6379"

JWT_SECRET_KEY = "UeCMQQglnc0O68rTJQezNNSt"
JWT_ISSUER = "http://localhost/oauth2"

# Logging: get rid of local handler
logging_config = get_logger_config(
    log_dir="/var/log",
    edx_filename="ecommerce_worker.log",
    dev_env=True,
    debug=False,
    local_loglevel="INFO",
)
logging_config["handlers"].pop("local")
for logger in logging_config["loggers"].values():
    try:
        logger["handlers"].remove("local")
    except ValueError:
        continue
logging.config.dictConfig(logging_config)