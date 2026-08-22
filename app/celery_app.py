"""
Celery application instance - separated to avoid circular imports
"""

import os
from celery import Celery

celery = Celery(__name__)
celery.conf.broker_connection_retry_on_startup = True
celery.conf.broker_url = os.environ.get("CELERY_BROKER_URL", "sqla+sqlite:///celery.sqlite")
celery.conf.result_backend = os.environ.get("CELERY_RESULT_BACKEND", "db+sqlite:///results.sqlite")
celery.conf.worker_hijack_root_logger = False
celery.conf.worker_redirect_stdouts_level = "DEBUG"
