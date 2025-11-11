# Aspects vs Panorama: Feature Comparison
_Audience: Leadership • Owner: Data/Analytics • Last verified: 2025-07-25_

This document explains what Panorama can do that Aspects cannot, helping you decide if you need Panorama in addition to (or instead of) Aspects.

## Quick Summary

**Aspects** is OpenEdX's native analytics solution - it's free, open-source, and provides comprehensive platform-wide analytics. **Panorama** is a third-party commercial solution that may offer additional features or a different user experience.

## What Aspects Provides (Native Solution)

✅ **Platform-wide analytics** - All courses, enrollments, completions in one place  
✅ **Free and open-source** - No licensing costs  
✅ **Apache Superset integration** - Powerful, flexible visualization tool  
✅ **Privacy-conscious** - Built-in data de-identification  
✅ **Real-time data processing** - Near real-time updates  
✅ **Custom dashboards** - Create your own reports and visualizations  
✅ **At-risk learner identification** - Identify learners who may not complete  
✅ **In-context analytics** - Analytics embedded in Studio  
✅ **Full control** - Deploy and configure as needed  

## What Panorama Can Do That Aspects Cannot

### 1. **Commercial Support & SLA**

**Panorama Advantage:**
- Dedicated commercial support team
- Service Level Agreements (SLAs) for uptime/support
- Guaranteed response times
- Professional services available

**Aspects:**
- Community support (forums, GitHub issues)
- No SLA guarantees
- Self-service troubleshooting

**When This Matters:**
- If you need guaranteed support response times
- If you require professional services for setup/customization
- If you need vendor accountability

---

### 2. **Pre-Built Dashboards & Templates**

**Panorama Advantage:**
- May include pre-configured dashboards tailored for common use cases
- Industry-specific templates (corporate training, higher ed, etc.)
- Out-of-the-box visualizations optimized for specific scenarios
- Less configuration required to get started

**Aspects:**
- Requires building custom dashboards in Superset
- More technical knowledge needed to create visualizations
- Flexible but requires more setup time

**When This Matters:**
- If you need analytics immediately without dashboard development
- If you lack technical resources to build custom dashboards
- If you want industry-specific templates

---

### 3. **Embedded UI Integration**

**Panorama Advantage:**
- May provide more seamless UI integration within OpenEdX
- Potentially more polished user experience
- May integrate more deeply into LMS navigation
- Could offer better mobile responsiveness

**Aspects:**
- Uses Superset (separate dashboard interface)
- Requires navigation to separate URL
- SSO integration available but separate interface

**When This Matters:**
- If you want analytics fully embedded in LMS UI
- If you prefer a single, unified interface
- If mobile-first experience is critical

---

### 4. **Advanced Analytics Features (Varies by Provider)**

**Panorama Advantage:**
- May include advanced features like:
  - Predictive analytics
  - Machine learning-based insights
  - Advanced cohort analysis
  - Custom algorithm implementations
  - Advanced segmentation tools
- Features depend on specific Panorama provider

**Aspects:**
- Basic analytics and reporting
- Custom SQL queries possible in Superset
- No built-in ML/predictive features
- Requires custom development for advanced features

**When This Matters:**
- If you need predictive analytics or ML insights
- If you require advanced statistical analysis
- If you need sophisticated cohort segmentation

---

### 5. **Ease of Use for Non-Technical Users**

**Panorama Advantage:**
- May offer simpler, more intuitive interface
- Less technical knowledge required
- More guided workflows
- Potentially better user training materials

**Aspects:**
- Superset requires some technical knowledge
- SQL knowledge helpful for custom queries
- Steeper learning curve
- More powerful but more complex

**When This Matters:**
- If non-technical staff need to use analytics regularly
- If you want minimal training requirements
- If simplicity is more important than flexibility

---

### 6. **Managed Service Option**

**Panorama Advantage:**
- Some providers offer fully managed/hosted solutions
- No infrastructure management required
- Automatic updates and maintenance
- Reduced operational overhead

**Aspects:**
- Self-hosted (you manage infrastructure)
- You handle updates and maintenance
- Full control but full responsibility

**When This Matters:**
- If you want to outsource infrastructure management
- If you lack DevOps resources
- If you prefer SaaS model

---

### 7. **Integration with External Tools**

**Panorama Advantage:**
- May offer pre-built integrations with:
  - Business Intelligence tools (Tableau, Power BI)
  - CRM systems
  - Marketing automation platforms
  - Other enterprise systems
- Easier data export/API access

**Aspects:**
- Can integrate via APIs and data exports
- Requires custom development for integrations
- More flexible but more work

**When This Matters:**
- If you need integrations with specific enterprise tools
- If you want pre-built connectors
- If you need seamless data flow to other systems

---

### 8. **Compliance & Certification**

**Panorama Advantage:**
- May offer specific compliance certifications
- Industry-specific compliance features
- Audit trails and compliance reporting
- Vendor assumes some compliance responsibility

**Aspects:**
- You're responsible for compliance
- Can be configured for compliance but requires setup
- Full control over compliance measures

**When This Matters:**
- If you need specific compliance certifications
- If you want vendor-backed compliance guarantees
- If compliance is a critical requirement

---

## Feature Comparison Table

| Feature | Aspects | Panorama |
|---------|---------|----------|
| **Cost** | ✅ Free (open-source) | ⚠️ Commercial (varies) |
| **Platform-wide Analytics** | ✅ Yes | ✅ Yes |
| **Custom Dashboards** | ✅ Yes (Superset) | ✅ Yes |
| **Pre-built Templates** | ❌ No | ✅ Maybe |
| **Commercial Support** | ❌ Community only | ✅ Yes |
| **Ease of Use** | ⚠️ Technical | ✅ Easier |
| **Advanced Analytics** | ⚠️ Basic | ✅ Advanced (varies) |
| **Managed Service** | ❌ Self-hosted | ✅ Maybe |
| **Native Integration** | ✅ Yes | ✅ Yes |
| **Privacy Controls** | ✅ Built-in | ✅ Yes |
| **Full Control** | ✅ Yes | ⚠️ Depends |

## Recommendation

### Start with Aspects Because:

1. ✅ **It's free** - No licensing costs
2. ✅ **It's native** - Built by OpenEdX team
3. ✅ **It's powerful** - Superset is industry-standard BI tool
4. ✅ **It's flexible** - Can customize everything
5. ✅ **It works** - Provides all core analytics needs

### Consider Panorama If:

1. ⚠️ **You need commercial support** - Require SLA-backed support
2. ⚠️ **You lack technical resources** - Need simpler, pre-built dashboards
3. ⚠️ **You need advanced features** - Require ML/predictive analytics
4. ⚠️ **You want managed service** - Prefer SaaS over self-hosting
5. ⚠️ **You need specific integrations** - Require pre-built connectors

## Decision Framework

**Use Aspects if:**
- ✅ You have technical resources
- ✅ You want full control
- ✅ Cost is a concern
- ✅ You're comfortable with Superset
- ✅ You need platform-wide analytics (Aspects provides this!)

**Use Panorama if:**
- ⚠️ You need commercial support/SLA
- ⚠️ You lack technical resources
- ⚠️ You need advanced analytics features
- ⚠️ You prefer managed service
- ⚠️ Budget allows for licensing

**Use Both if:**
- You want Aspects for core analytics
- You need Panorama for specific advanced features
- You can afford both

## Conclusion

**Aspects provides everything you need for platform-wide analytics** - enrollments, completions, certificates, engagement metrics, and more. It's free, powerful, and native to OpenEdX.

**Panorama's advantages are primarily around:**
- Commercial support and SLAs
- Ease of use for non-technical users
- Pre-built templates and dashboards
- Advanced analytics features (varies by provider)
- Managed service options

**Our recommendation:** Start with Aspects. It provides all the core platform-wide analytics you need. Only consider Panorama if you have specific requirements that Aspects doesn't meet (like commercial support, advanced ML features, or managed service).

## Next Steps

1. ✅ **Aspects is installed** - Complete the Docker image build and initialization
2. ✅ **Test Aspects** - Use it for platform-wide analytics
3. ⚠️ **Evaluate needs** - Determine if Aspects meets all requirements
4. ⚠️ **Consider Panorama** - Only if Aspects lacks specific features you need

