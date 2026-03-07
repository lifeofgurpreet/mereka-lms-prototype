# Panorama Analytics - Third-Party Analytics Platform
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

Panorama is a **third-party analytics tool** that provides embedded analytics directly within the OpenEdX interface. It offers comprehensive dashboards for both administrators and students, with enhanced visualization and reporting capabilities.

## Overview

Panorama provides:
- **Embedded analytics** directly in OpenEdX LMS
- **Administrator dashboards** for platform-wide insights
- **Student dashboards** for personal progress tracking
- **Role-based access** control for data visibility
- **Enhanced visualizations** beyond standard OpenEdX reports

## Key Features

### Administrator Dashboards

- **Platform Overview**: Cross-course analytics and trends
- **Enrollment Analytics**: Total enrollments, trends, by course
- **Completion Analytics**: Completion rates, certificates issued
- **Grade Analytics**: Performance metrics across courses
- **Learner Analytics**: Individual and cohort performance
- **Engagement Metrics**: Activity patterns and trends

### Student Dashboards

- **Personal Progress**: Course completion status
- **Grades**: Performance across enrolled courses
- **Certificates**: Earned certificates
- **Activity**: Personal engagement metrics

### Access Control

- **Role-based permissions**: Control who sees what data
- **Customizable access**: Assign dashboard access by user role
- **Privacy controls**: Configurable data visibility

## Installation

Panorama requires separate installation and integration. The exact steps depend on your Panorama provider.

### General Installation Steps

1. **Obtain Panorama License/Account**
   - Contact Panorama provider or check marketplace
   - Obtain API keys and integration credentials

2. **Install Panorama Plugin**
   ```bash
   # Installation method varies by provider
   # Typically involves:
   pip install panorama-analytics-plugin
   # or
   tutor plugins enable panorama
   ```

3. **Configure Integration**
   - Add API keys to Tutor config
   - Configure data sync settings
   - Set up authentication

4. **Enable in OpenEdX**
   - Add Panorama settings to Django config
   - Configure LMS/CMS integration
   - Set up user permissions

### Configuration Example

```yaml
# In tutor_env/config.yml
PANORAMA_API_KEY: "your-api-key"
PANORAMA_API_SECRET: "your-api-secret"
PANORAMA_ENABLED: true
PANORAMA_DASHBOARD_URL: "https://panorama.yourdomain.com"
```

## Accessing Panorama

### From LMS Header

- Look for **"Analytics"** or **"Panorama"** link in the LMS header
- Click to access the analytics dashboard
- Single sign-on with LMS credentials

### From Instructor Dashboard

- Navigate to course → Instructor Dashboard
- Look for **"Panorama Analytics"** section
- Access course-specific or platform-wide analytics

### Direct Access

- Panorama may be available at a custom route
- Check with your Panorama provider for exact URL
- Typically: `https://your-lms-domain.com/analytics` or similar

## Features Comparison

### Platform-Wide Analytics

✅ **Yes** - Panorama provides comprehensive platform-wide analytics:
- All courses in one view
- Cross-course comparisons
- Platform trends and metrics
- Aggregated enrollment/completion data

### Custom Dashboards

✅ **Yes** - Create custom dashboards:
- Drag-and-drop dashboard builder
- Custom metrics and KPIs
- Scheduled reports
- Export capabilities

### Real-Time Data

⚠️ **Depends** - Data freshness depends on sync configuration:
- May have slight delay (minutes to hours)
- Configurable sync frequency
- Real-time options may be available

## Integration Methods

### API Integration

Panorama typically integrates via:
- **REST API**: For data synchronization
- **Webhooks**: For real-time event updates
- **Database Access**: Direct database queries (if permitted)

### Data Sync

- **Scheduled Syncs**: Periodic data updates
- **Real-Time Sync**: Event-driven updates
- **Manual Sync**: On-demand data refresh

## Configuration Options

### Data Collection

Configure what data Panorama collects:
- Enrollments
- Completions
- Grades
- Certificates
- User activity
- Course content

### Privacy Settings

- **Data anonymization**: De-identify learner data
- **Access controls**: Role-based data visibility
- **Compliance**: GDPR and other regulations

### Customization

- **Branding**: Match OpenEdX theme
- **Dashboards**: Custom layouts and metrics
- **Reports**: Scheduled and on-demand reports
- **Alerts**: Notifications for key metrics

## Troubleshooting

### Panorama Not Appearing

1. **Check installation**: Verify plugin is installed and enabled
2. **Check configuration**: Verify API keys and settings
3. **Check permissions**: Ensure user has access
4. **Check logs**: Review LMS logs for errors

### Data Not Syncing

1. **Check API connection**: Verify API keys are correct
2. **Check sync schedule**: Verify sync is configured
3. **Check permissions**: Ensure Panorama can access data
4. **Check logs**: Review sync logs for errors

### Access Issues

1. **Check user role**: Verify user has appropriate permissions
2. **Check dashboard access**: Verify dashboard is assigned to user
3. **Check SSO**: Verify single sign-on is configured correctly

## Cost Considerations

Panorama may have:
- **License fees**: Per user or per course
- **Usage fees**: Based on data volume
- **Support fees**: For premium support

**Check with provider** for exact pricing model.

## Alternatives

If Panorama doesn't meet your needs, consider:

1. **Aspects Analytics**: OpenEdX's native solution (see `docs/concepts/analytics/ASPECTS_ANALYTICS.md`)
2. **Custom Dashboards**: Build using OpenEdX APIs
3. **Third-Party BI Tools**: Integrate with Power BI, Tableau, etc.
4. **Self-Hosted Solutions**: Deploy your own analytics stack

## Resources

- **Panorama Announcement**: https://discuss.openedx.org/t/panorama-new-embedded-analytics-experience-for-open-edx-staff-and-students/13315
- **Provider Documentation**: Check with your Panorama provider
- **OpenEdX Marketplace**: May have Panorama listings

## Recommendation

**Before choosing Panorama**:

1. ✅ **Try Aspects first** - It's free, native, and provides platform-wide analytics
2. ⚠️ **Evaluate costs** - Panorama may have licensing fees
3. ⚠️ **Check features** - Ensure Panorama has features Aspects lacks
4. ⚠️ **Consider support** - Verify provider support quality

**Use Panorama if**:
- You need specific features Aspects doesn't provide
- You prefer Panorama's UI/UX
- You have budget for licensing
- You need dedicated support

**Use Aspects if**:
- You want free, open-source solution
- You prefer native OpenEdX integration
- You want full control over deployment
- You're comfortable with Superset

## Next Steps

1. **Evaluate Aspects** first (see `docs/concepts/analytics/ASPECTS_ANALYTICS.md`)
2. **Contact Panorama provider** if you need Panorama-specific features
3. **Compare costs** and features
4. **Make decision** based on your needs and budget

