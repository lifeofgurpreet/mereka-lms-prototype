# Local Access Guide - Everything You Need
_Last updated: 2025-11-12_

## 🌐 Step 1: Add Domain to /etc/hosts

Run this command:
```bash
echo '127.0.0.1 skillourfuture.staging.academy.mereka.io' | sudo tee -a /etc/hosts
```

## 📍 Access URLs

### Skill Our Future (MCT Courses)
**URL:** http://skillourfuture.staging.academy.mereka.io  
**Login:** admin / admin123  
**Courses:** 2 SKILLOURFUTURE courses from production

### Studio (Course Authoring)
**URL:** http://studio.localhost  
**Login:** admin / admin123  
**Purpose:** Edit courses, view content, manage settings

### Main LMS
**URL:** http://localhost  
**Login:** admin / admin123  
**Purpose:** Future Kajabi courses will be here

## 📊 Analytics (Superset)

**URL:** http://superset.localhost

**Credentials:**
- **Username:** `UOTbuYNBM0Tw`
- **Password:** `0ui3DwG7yQfQTYwXOP7G1NS7`

**What You Can See:**
- Student enrollment data
- Course completion rates
- Learning analytics dashboards
- User activity reports

## 🎓 Your Courses (Synced from Production)

### 1. MCTCAT-24
- **ID:** `course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24`
- **Organization:** SKILLOURFUTURE
- **Access:** Studio or Skill Our Future LMS

### 2. MCTCAT-16
- **ID:** `course-v1:SKILLOURFUTURE+MCTCAT-16+RUN-16`
- **Organization:** SKILLOURFUTURE
- **Access:** Studio or Skill Our Future LMS

## 👥 Users

**Total:** 84,378 MCT users  
**Source:** All from Microsoft Community Training  
**Kajabi:** Not imported yet (ready for when they are)

## 🔄 To Refresh from Production

```bash
./tools/sync-from-production.sh
```

This will:
- Pull latest courses from production MongoDB
- Update user tags
- Refresh course-domain mappings

## 🛠️ Troubleshooting

### Can't access skillourfuture domain
```bash
# Check hosts file
cat /etc/hosts | grep skillourfuture

# If not there, add it:
echo '127.0.0.1 skillourfuture.staging.academy.mereka.io' | sudo tee -a /etc/hosts
```

### Courses not showing
```bash
# Generate course overviews
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms generate_course_overview --all
```

### Superset login fails
```bash
# Get credentials from config
grep -E "SUPERSET.*USER|SUPERSET.*PASS" tutor_env/config.yml
```

### Need to restart everything
```bash
tutor local restart
```

## 📈 What to Check

### 1. In Studio
- View both courses
- Check course structure
- View units and content
- Edit course settings

### 2. In Skill Our Future LMS
- Browse as a student
- View course catalog
- Check enrollment

### 3. In Superset
- View dashboards
- Check student data
- Export reports

## 🎯 Next Steps

1. **Add domain to hosts** (run command above)
2. **Open Studio** at http://studio.localhost
3. **Login** with admin/admin123
4. **View courses** - you should see both SKILLOURFUTURE courses
5. **Open Superset** at http://superset.localhost
6. **Login with Superset credentials** (see above)
7. **Explore analytics dashboards**

---

**Everything is ready!** Your 2 courses, 84K users, and analytics are all running locally. 🎉



