from django.contrib import admin

from .models import TenantConfig


@admin.register(TenantConfig)
class TenantConfigAdmin(admin.ModelAdmin):
    list_display = ("slug", "enterprise_customer", "is_active", "provisioned_at")
    list_filter = ("is_active",)
    search_fields = ("slug", "enterprise_customer__name")
    readonly_fields = ("provisioned_at", "updated_at")
