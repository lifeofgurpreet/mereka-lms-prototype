# Aspects Analytics - Platform-Wide Analytics for OpenEdX
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

Aspects is OpenEdX's **native analytics system** that provides comprehensive, platform-wide analytics across all courses. It's designed to be privacy-conscious and provides actionable insights into learner engagement, course performance, and overall platform metrics.

## Overview

Aspects integrates several open-source tools to provide:
- **Platform-wide dashboards** (not just per-course)
- **Real-time data processing** with near real-time updates
- **Customizable reports** and visualizations
- **Privacy-conscious** data handling (de-identifies learner data by default)
- **Apache Superset integration** for advanced data visualization

## Key Features

### Dashboards Available

1. **Course Dashboard** - Enrollment, engagement, and performance metrics for all courses
2. **At-Risk Learners Dashboard** - Identifies learners who may be at risk of not completing
3. **Individual Learner Dashboard** - Detailed activity data for individual learners
4. **Platform Overview** - Cross-course analytics and trends
5. **In-Context Dashboards** - Analytics embedded in Studio when editing content

### Metrics Tracked

- **Enrollments**: Total enrollments, enrollment trends, enrollment by course
- **Completions**: Completion rates, completion trends, certificates issued
- **Engagement**: Login frequencies, content interactions, time spent
- **Performance**: Grades, assessment scores, problem-level analytics
- **Learner Behavior**: Activity patterns, engagement patterns, risk factors

## Installation

Aspects is installed as a Tutor plugin. Follow these steps:

### 1. Install the Aspects Plugin

```bash
source infrastructure/tutor/tutor-env.sh

# Install the plugin
pip install tutor-contrib-aspects

# Enable the plugin
tutor plugins enable aspects

# Save configuration
tutor config save
```

### 2. Rebuild Docker Images

```bash
# Rebuild OpenEdX images (required for Aspects integration)
tutor images build openedx --no-cache

# Rebuild MFE images (only if using in-context metrics)
tutor images build mfe --no-cache

# Build Aspects-specific images
tutor images build aspects aspects-superset
```

### 3. Initialize the Environment

```bash
# Initialize Aspects services
tutor local do init

# Start all services
tutor local start -d
```

### 4. Verify Installation

Check that Aspects services are running:

```bash
tutor local dc ps | grep aspects
```

You should see:
- `aspects-clickhouse` - Data warehouse
- `aspects-superset` - Visualization dashboard
- `aspects-event-routing` - Event processing

## Configuration

### Basic Configuration

Aspects configuration is added to your `tutor_env/config.yml` when you enable the plugin. Key settings:

```yaml
# Aspects configuration (auto-generated when plugin is enabled)
ASPECTS_ENABLE_SEND_LEARNER_DATA: true
ASPECTS_ENABLE_SEND_BLOCK_DATA: true
ASPECTS_ENABLE_SEND_GRADE_DATA: true
```

### Accessing Superset Dashboard

After installation, Superset (the visualization tool) is available at:

- **Local**: `http://aspects-superset.localhost`
- **Staging**: `https://aspects-superset.academyv2.mereka.io` (if configured)

**Default credentials**:
- Username: `admin`
- Password: Check `tutor local do printroot` or reset with `tutor local do init`

### Single Sign-On (SSO)

Aspects integrates with OpenEdX for SSO. LMS users with appropriate permissions can access Superset using their LMS credentials.

## Accessing Analytics

### From the LMS

1. **Instructor Dashboard Integration**:
   - Navigate to any course → Instructor Dashboard
   - Look for **"Reports"** link (new tab added by Aspects)
   - Click to access course-level dashboards

2. **Direct Superset Access**:
   - Log into Superset dashboard
   - Navigate to "Dashboards" menu
   - Access platform-wide or course-specific dashboards

### From Studio

- **Analytics Sidebar**: When editing course content, Aspects provides in-context analytics
- Shows engagement metrics for specific content sections
- Displays problem-level analytics

### Platform-Wide Access

Superusers and site operators can:
- View data for **any course** or **all courses**
- Access platform-wide dashboards
- Create custom reports and visualizations
- Export data for further analysis

## Usage Examples

### Viewing Enrollment Trends

1. Log into Superset
2. Navigate to "Dashboards" → "Course Overview"
3. View enrollment trends across all courses
4. Filter by date range, course, or other dimensions

### Identifying At-Risk Learners

1. Access "At-Risk Learners Dashboard" from Instructor Dashboard
2. View learners flagged based on:
   - Low engagement
   - Missing assignments
   - Low quiz scores
   - Inactivity periods

### Creating Custom Reports

1. In Superset, go to "Charts" → "Create Chart"
2. Select data source (Aspects ClickHouse)
3. Choose visualization type
4. Configure metrics and filters
5. Save as dashboard

## Architecture

Aspects uses:

- **ClickHouse**: Data warehouse for storing learning events
- **Apache Superset**: Visualization and dashboarding tool
- **Event Routing**: Captures learning events from OpenEdX
- **Data Pipeline**: Processes and transforms events into analytics-ready data

## Data Privacy

Aspects is designed with privacy in mind:

- **De-identification**: Learner data is de-identified by default
- **Configurable**: Can be configured to include/exclude specific data types
- **Compliance**: Supports GDPR and other privacy regulations

## Troubleshooting

### Aspects Services Not Starting

```bash
# Check logs
tutor local logs aspects-clickhouse --tail=50
tutor local logs aspects-superset --tail=50

# Restart services
tutor local restart aspects-clickhouse aspects-superset
```

### Can't Access Superset

1. **Check service is running**: `tutor local dc ps | grep superset`
2. **Check URL**: Verify the hostname is configured correctly
3. **Check credentials**: Reset with `tutor local do init`
4. **Check firewall**: Ensure port is accessible

### No Data Showing

1. **Check event routing**: Verify events are being captured
2. **Check ClickHouse**: Ensure data is being written
3. **Wait for processing**: Data may take a few minutes to appear
4. **Check permissions**: Ensure user has access to dashboards

### Performance Issues

- **ClickHouse resources**: May need to increase memory/CPU
- **Superset caching**: Enable caching for frequently accessed dashboards
- **Data retention**: Configure retention policies to manage data volume

## Advanced Configuration

### Custom Event Tracking

Configure which events Aspects captures:

```yaml
ASPECTS_ENABLE_SEND_LEARNER_DATA: true
ASPECTS_ENABLE_SEND_BLOCK_DATA: true
ASPECTS_ENABLE_SEND_GRADE_DATA: true
ASPECTS_ENABLE_SEND_COURSE_DATA: true
```

### Data Retention

Configure how long data is retained:

```yaml
ASPECTS_CLICKHOUSE_DATA_RETENTION_DAYS: 365
```

### Superset Customization

- Custom dashboards
- Custom charts
- Custom data sources
- User roles and permissions

## Kubernetes Deployment

For production/dev deployments:

```bash
# Generate Kubernetes config
tutor k8s quickstart

# Deploy Aspects services
tutor k8s init
tutor k8s start

# Verify deployment
kubectl get pods -n mereka-lms | grep aspects
```

## Resources

- **Official Documentation**: https://docs.openedx.org/projects/openedx-aspects/
- **GitHub Repository**: https://github.com/openedx/tutor-contrib-aspects
- **Aspects Plugin**: https://github.com/openedx/tutor-contrib-aspects
- **Superset Documentation**: https://superset.apache.org/docs/

## Next Steps

1. **Install Aspects** using the steps above
2. **Configure data collection** based on your needs
3. **Set up dashboards** for your key metrics
4. **Train staff** on using Superset
5. **Create custom reports** for specific use cases

## Comparison with Panorama

| Feature | Aspects | Panorama |
|---------|---------|----------|
| **Native Integration** | ✅ Yes (OpenEdX official) | ❌ Third-party |
| **Platform-Wide Analytics** | ✅ Yes | ✅ Yes |
| **Privacy Controls** | ✅ Built-in | ✅ Available |
| **Customization** | ✅ High (Superset) | ✅ High |
| **Installation** | ✅ Tutor plugin | ⚠️ Separate setup |
| **Cost** | ✅ Free (open source) | ⚠️ May have costs |

**Recommendation**: Start with Aspects as it's the official OpenEdX solution. Consider Panorama if you need specific features Aspects doesn't provide.
