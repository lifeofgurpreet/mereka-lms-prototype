# -*- coding: utf-8 -*-
"""Canonical public footer content shared by LMS and MFE shells."""

from copy import deepcopy


_MEREKA_PUBLIC_FOOTER = {
    "brand": {
        "logoText": "mereka",
    },
    "socialLinks": [
        {
            "name": "TikTok",
            "url": "https://www.tiktok.com/@mereka.io",
            "iconPath": "M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z",
        },
        {
            "name": "Instagram",
            "url": "https://www.instagram.com/mereka.io/",
            "iconPath": "M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z",
        },
        {
            "name": "Facebook",
            "url": "https://www.facebook.com/mereka.io",
            "iconPath": "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z",
        },
        {
            "name": "LinkedIn",
            "url": "https://www.linkedin.com/company/mereka/",
            "iconPath": "M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z",
        },
        {
            "name": "YouTube",
            "url": "https://www.youtube.com/channel/UCCyMH5KIZeCMchjMKl7RWxg",
            "iconPath": "M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z",
        },
    ],
    "navLinks": [
        {"label": "About", "url": "https://corporate.mereka.io/about-us"},
        {"label": "Andragogy", "url": "https://corporate.mereka.io/andragogy"},
        {"label": "Portfolio", "url": "https://corporate.mereka.io/portfolio"},
        {"label": "Team", "url": "https://corporate.mereka.io/our-team"},
        {"label": "Careers", "url": "https://corporate.mereka.io/work-with-us"},
        {"label": "Ecosystem", "url": "https://corporate.mereka.io/ecosystem"},
        {"label": "Blog", "url": "https://corporate.mereka.io/blog"},
    ],
    "support": {
        "helpLabel": "Help Centre",
        "contactSupportLabel": "Contact Support",
        "contactCtaLabel": "Contact Us",
        "whatsapp": "601135271981",
    },
    "sections": {
        "corporate": {
            "title": "Corporate",
            "links": [
                {"label": "Accelerate Talent", "url": "https://corporate.mereka.io/academy/funders"},
                {"label": "Create Online Course", "url": "https://corporate.mereka.io/academy/create-online-courses"},
                {"label": "Build a Makerspace", "url": "https://corporate.mereka.io/academy/makerspace"},
            ],
        },
        "marketplace": {
            "title": "Marketplace",
            "usersHeading": "USERS",
            "userLinks": [
                {"label": "Experiences", "url": "https://mereka.io/experiences"},
                {"label": "Experts", "url": "https://mereka.io/experts"},
                {"label": "Expertise", "url": "https://mereka.io/expertise"},
                {"label": "Hubs", "url": "https://mereka.io/hubs"},
                {"label": "Spaces", "url": "https://corporate.mereka.io/space"},
            ],
            "businessHeading": "BUSINESS",
            "businessLinks": [
                {"label": "Pricing", "url": "https://hubs.mereka.io/pricing"},
                {"label": "Solutions", "url": "https://hubs.mereka.io/howitworks"},
            ],
            "appLabel": "Manage your bookings",
            "appBadges": [
                {"label": "App Store", "url": "https://apps.apple.com/id/app/mereka-hubs/id6473277964"},
                {"label": "Google Play", "url": "https://play.google.com/store/apps/details?id=io.mereka.hubs"},
            ],
            "cta": {
                "label": "Become a Hub",
                "url": "https://mereka.io/welcome/hub",
            },
        },
        "academy": {
            "title": "Academy",
            "links": [
                {"label": "Future of Work", "url": "https://corporate.mereka.io/academy/future-of-work"},
                {"label": "Digital Entrepreneur", "url": "https://corporate.mereka.io/academy/digital-entrepreneur"},
                {"label": "All Courses", "url": "https://corporate.mereka.io/academy/all-courses"},
            ],
        },
        "space": {
            "title": "Space",
            "links": [
                {"label": "Mereka @ Publika", "url": "https://corporate.mereka.io/publika"},
                {"label": "Our Labs", "url": "https://corporate.mereka.io/space#labs"},
                {"label": "Bespoke Design", "url": "https://corporate.mereka.io/space/innovate#products"},
                {"label": "Host Events", "url": "https://corporate.mereka.io/space#event-cta"},
            ],
        },
    },
    "legal": {
        "termsLabel": "TERMS OF USE",
        "privacyLabel": "PRIVACY POLICY",
        "cookiesLabel": "COOKIES POLICY",
    },
}


def build_mereka_public_footer():
    """Return a defensive copy of the canonical shared footer content."""
    return deepcopy(_MEREKA_PUBLIC_FOOTER)
