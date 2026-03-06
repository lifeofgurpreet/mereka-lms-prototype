# Ecommerce Template Theming Guide

<!-- Last verified: 2026-02-13 -->

> **DEPRECATED**: This document covers theming for the legacy Oscar-based ecommerce service. The custom Purchase Gateway (`services/purchase-gateway/`) uses its own frontend and does not require Oscar template overrides. This document is retained for reference during the transition period.

This document covers theming Open edX ecommerce templates for Mereka branding, including basket, checkout, receipt pages, and payment MFE integration.

## Ecommerce Architecture

### Template System
- **Base**: Django Oscar templates (e-commerce framework)
- **Override**: Place custom templates in `tutor_env/plugins/ecommerce/templates/`
- **Static Assets**: CSS/JS in `tutor_env/plugins/ecommerce/static/`

### Key Pages
1. **Basket** (`/basket/`) - Shopping cart
2. **Checkout** (`/checkout/`) - Payment information
3. **Receipt** (`/checkout/receipt/`) - Order confirmation
4. **Payment MFE** - Embedded payment micro-frontend

## Design Token Application

### Mereka Design Tokens

Tokens defined in `infrastructure/tutor/branding/design-tokens.yml`:

```yaml
colors:
  primary: "#FF6B35"        # Mereka orange
  secondary: "#004E89"      # Mereka blue
  accent: "#F7B801"         # Mereka yellow
  text:
    primary: "#1A1A1A"
    secondary: "#4A4A4A"
  background:
    light: "#FFFFFF"
    neutral: "#F5F5F5"

typography:
  fontFamily:
    primary: "'Inter', sans-serif"
    heading: "'Poppins', sans-serif"

spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
```

### CSS Variable Mapping

Create `tutor_env/plugins/ecommerce/static/css/mereka-theme.css`:

```css
:root {
  /* Colors */
  --mereka-primary: #FF6B35;
  --mereka-secondary: #004E89;
  --mereka-accent: #F7B801;
  --mereka-text-primary: #1A1A1A;
  --mereka-text-secondary: #4A4A4A;
  --mereka-bg-light: #FFFFFF;
  --mereka-bg-neutral: #F5F5F5;

  /* Typography */
  --mereka-font-primary: 'Inter', sans-serif;
  --mereka-font-heading: 'Poppins', sans-serif;

  /* Spacing */
  --mereka-spacing-xs: 4px;
  --mereka-spacing-sm: 8px;
  --mereka-spacing-md: 16px;
  --mereka-spacing-lg: 24px;
  --mereka-spacing-xl: 32px;
}
```

## Template Override Points

### Basket Page (`basket.html`)

**Override Location**: `tutor_env/plugins/ecommerce/templates/basket/basket.html`

**Key Elements**:
```django
{% extends "oscar/basket/basket.html" %}
{% load static %}

{% block extra_head %}
  <link rel="stylesheet" href="{% static 'css/mereka-theme.css' %}">
{% endblock %}

{% block header %}
  <header style="background-color: var(--mereka-primary);">
    <img src="{% static 'images/mereka-logo.svg' %}" alt="Mereka Academy">
  </header>
{% endblock %}

{% block basket_content %}
  <div class="basket-content" style="font-family: var(--mereka-font-primary);">
    {{ block.super }}
  </div>
{% endblock %}
```

### Checkout Page (`checkout.html`)

**Override Location**: `tutor_env/plugins/ecommerce/templates/checkout/checkout.html`

**Branding Points**:
- Header logo
- Primary button colors
- Form field styling
- Payment method icons

**Example**:
```django
{% extends "oscar/checkout/checkout.html" %}

{% block checkout_nav %}
  <nav class="checkout-nav" style="background: var(--mereka-bg-neutral);">
    <ol class="checkout-steps">
      {% for step in checkout_steps %}
        <li style="color: var(--mereka-secondary);">{{ step }}</li>
      {% endfor %}
    </ol>
  </nav>
{% endblock %}

{% block payment_method %}
  <div class="payment-method" style="
    border: 2px solid var(--mereka-primary);
    padding: var(--mereka-spacing-md);
  ">
    {{ block.super }}
  </div>
{% endblock %}
```

### Receipt Page (`receipt.html`)

**Override Location**: `tutor_env/plugins/ecommerce/templates/checkout/receipt.html`

**Branding Points**:
- Confirmation message styling
- Order summary table
- Call-to-action buttons

**Example**:
```django
{% extends "oscar/checkout/receipt.html" %}

{% block receipt_content %}
  <div class="receipt-content" style="font-family: var(--mereka-font-primary);">
    <h1 style="
      font-family: var(--mereka-font-heading);
      color: var(--mereka-primary);
    ">
      Order Confirmed!
    </h1>
    {{ block.super }}
  </div>
{% endblock %}

{% block order_actions %}
  <a href="{% url 'dashboard:index' %}" class="btn btn-primary" style="
    background-color: var(--mereka-primary);
    border: none;
    padding: var(--mereka-spacing-md) var(--mereka-spacing-lg);
  ">
    Go to Dashboard
  </a>
{% endblock %}
```

## Payment MFE Theming

### MFE Configuration

Payment micro-frontend uses Paragon design system:

**Config** (`tutor_env/plugins/mfe/config.json`):
```json
{
  "PAYMENT_MFE_CONFIG": {
    "theme": {
      "brandPrimary": "#FF6B35",
      "brandSecondary": "#004E89",
      "fontFamily": "'Inter', sans-serif"
    }
  }
}
```

### Custom Paragon Variables

Create `tutor_env/plugins/mfe/payment/custom.scss`:

```scss
// Import Mereka tokens
@import 'mereka-tokens';

// Override Paragon variables
$primary: $mereka-primary;
$secondary: $mereka-secondary;
$font-family-base: $mereka-font-primary;
$font-family-headings: $mereka-font-heading;

// Button styles
.btn-primary {
  background-color: $mereka-primary;
  border-color: $mereka-primary;

  &:hover {
    background-color: darken($mereka-primary, 10%);
  }
}

// Form inputs
.form-control {
  font-family: $mereka-font-primary;
  border-color: $mereka-secondary;

  &:focus {
    border-color: $mereka-primary;
    box-shadow: 0 0 0 0.2rem rgba(255, 107, 53, 0.25);
  }
}
```

## Baseline Screenshot Capture

Use the branding screenshot script:

```bash
# Capture baseline screenshots
./scripts/qa/capture-branding-screenshots.sh --target ecommerce

# Screenshots saved to:
# - var/screenshots/ecommerce/basket-{timestamp}.png
# - var/screenshots/ecommerce/checkout-{timestamp}.png
# - var/screenshots/ecommerce/receipt-{timestamp}.png
```

**Manual Capture**:
1. Navigate to ecommerce page
2. Open browser dev tools
3. Toggle device toolbar (responsive mode)
4. Viewport: 1440x900 (desktop), 375x812 (mobile)
5. Capture full-page screenshot

## CSS Override Approach

### Global Overrides

**File**: `tutor_env/plugins/ecommerce/static/css/oscar-overrides.css`

```css
/* Oscar base overrides */
.basket-title,
.checkout-title {
  font-family: var(--mereka-font-heading);
  color: var(--mereka-primary);
}

.btn-primary {
  background-color: var(--mereka-primary);
  border-color: var(--mereka-primary);
}

.btn-primary:hover {
  background-color: #E55A2D; /* Darker Mereka orange */
}

/* Table styling */
.table {
  font-family: var(--mereka-font-primary);
}

.table thead th {
  background-color: var(--mereka-bg-neutral);
  color: var(--mereka-secondary);
}

/* Form styling */
.form-control {
  border-color: var(--mereka-secondary);
  font-family: var(--mereka-font-primary);
}

.form-control:focus {
  border-color: var(--mereka-primary);
  box-shadow: 0 0 0 0.2rem rgba(255, 107, 53, 0.25);
}
```

### Component-Specific Overrides

**Basket Summary**:
```css
.basket-summary {
  border: 2px solid var(--mereka-primary);
  border-radius: 8px;
  padding: var(--mereka-spacing-md);
}

.basket-total {
  font-family: var(--mereka-font-heading);
  font-size: 24px;
  color: var(--mereka-primary);
}
```

**Checkout Steps**:
```css
.checkout-steps li.active {
  color: var(--mereka-primary);
  font-weight: 600;
}

.checkout-steps li::before {
  background-color: var(--mereka-primary);
}
```

## Deployment Workflow

1. **Develop**: Modify templates in `tutor_env/plugins/ecommerce/`
2. **Test Locally**: `tutor local restart ecommerce`
3. **Capture Screenshots**: `./scripts/qa/capture-branding-screenshots.sh --target ecommerce`
4. **Build Image**: `tutor images build ecommerce`
5. **Deploy**: Follow `docs/operations/THEME_DEPLOYMENT.md`

## Verification

```bash
# Verify CSS loaded
curl https://ecommerce.academyv2.mereka.io/basket/ | grep mereka-theme.css

# Check template overrides
kubectl exec -it -n mereka-lms deploy/ecommerce -- ls -la /openedx/ecommerce/templates/basket/

# Visual regression test
./scripts/qa/visual-regression-branding.sh --target ecommerce
```

## Related Documentation

- `docs/operations/THEME_DEPLOYMENT.md` - Full deployment guide
- `docs/guides/branding/BRANDING.md` - Branding system overview
- `infrastructure/tutor/branding/` - Design tokens and assets
