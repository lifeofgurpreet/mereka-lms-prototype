// i18n — lightweight internationalization framework
// Supports: en, ms (Bahasa Malaysia), id (Bahasa Indonesia), zh (Chinese Simplified)
// Usage: import { t, setLocale, getLocale } from '../i18n/index.js';

const SUPPORTED_LOCALES = ['en', 'ms', 'id', 'zh'];
const DEFAULT_LOCALE = 'en';

let _currentLocale = localStorage.getItem('mereka.locale') || DEFAULT_LOCALE;
let _translations = {};

// Translation dictionaries
const dictionaries = {
  en: {
    // Navigation
    'nav.dashboard': 'Dashboard',
    'nav.discover': 'Discover',
    'nav.mylearning': 'My Learning',
    'nav.studio': 'Studio',
    'nav.wishlist': 'Wishlist',
    'nav.profile': 'Profile',
    'nav.settings': 'Settings',
    'nav.notifications': 'Notifications',
    // Dashboard
    'dashboard.welcome': 'Welcome back, {name}',
    'dashboard.continue': 'Continue learning',
    'dashboard.deadlines': 'Upcoming deadlines',
    'dashboard.certificates': 'Recent certificates',
    'dashboard.discover': 'Discover courses',
    // Course
    'course.enroll': 'Enroll now',
    'course.continue': 'Continue',
    'course.completed': 'Completed',
    'course.modules': '{count} modules',
    'course.progress': '{percent}% complete',
    // General
    'general.loading': 'Loading…',
    'general.error': 'Something went wrong',
    'general.retry': 'Try again',
    'general.save': 'Save',
    'general.cancel': 'Cancel',
    'general.search': 'Search',
    'general.noResults': 'No results found',
    'general.viewAll': 'View all',
    // Auth
    'auth.signin': 'Sign in',
    'auth.signout': 'Sign out',
    'auth.register': 'Create account',
    // Accessibility
    'a11y.skipToContent': 'Skip to main content',
    'a11y.menu': 'Menu',
    'a11y.closeMenu': 'Close menu',
    'a11y.openMenu': 'Open menu',
  },
  ms: {
    'nav.dashboard': 'Papan Pemuka',
    'nav.discover': 'Terokai',
    'nav.mylearning': 'Pembelajaran Saya',
    'nav.studio': 'Studio',
    'nav.wishlist': 'Senarai Hajat',
    'nav.profile': 'Profil',
    'nav.settings': 'Tetapan',
    'nav.notifications': 'Pemberitahuan',
    'dashboard.welcome': 'Selamat kembali, {name}',
    'dashboard.continue': 'Teruskan pembelajaran',
    'dashboard.deadlines': 'Tarikh akhir akan datang',
    'dashboard.certificates': 'Sijil terkini',
    'dashboard.discover': 'Terokai kursus',
    'course.enroll': 'Daftar sekarang',
    'course.continue': 'Teruskan',
    'course.completed': 'Selesai',
    'course.modules': '{count} modul',
    'course.progress': '{percent}% siap',
    'general.loading': 'Memuatkan…',
    'general.error': 'Sesuatu tidak kena',
    'general.retry': 'Cuba lagi',
    'general.save': 'Simpan',
    'general.cancel': 'Batal',
    'general.search': 'Cari',
    'general.noResults': 'Tiada hasil ditemui',
    'general.viewAll': 'Lihat semua',
    'auth.signin': 'Log masuk',
    'auth.signout': 'Log keluar',
    'auth.register': 'Cipta akaun',
    'a11y.skipToContent': 'Langkau ke kandungan utama',
    'a11y.menu': 'Menu',
    'a11y.closeMenu': 'Tutup menu',
    'a11y.openMenu': 'Buka menu',
  },
  id: {
    'nav.dashboard': 'Dasbor',
    'nav.discover': 'Jelajahi',
    'nav.mylearning': 'Pembelajaran Saya',
    'nav.studio': 'Studio',
    'nav.wishlist': 'Daftar Keinginan',
    'nav.profile': 'Profil',
    'nav.settings': 'Pengaturan',
    'nav.notifications': 'Notifikasi',
    'dashboard.welcome': 'Selamat datang kembali, {name}',
    'dashboard.continue': 'Lanjutkan belajar',
    'dashboard.deadlines': 'Tenggat waktu mendatang',
    'dashboard.certificates': 'Sertifikat terbaru',
    'dashboard.discover': 'Temukan kursus',
    'course.enroll': 'Daftar sekarang',
    'course.continue': 'Lanjutkan',
    'course.completed': 'Selesai',
    'course.modules': '{count} modul',
    'course.progress': '{percent}% selesai',
    'general.loading': 'Memuat…',
    'general.error': 'Terjadi kesalahan',
    'general.retry': 'Coba lagi',
    'general.save': 'Simpan',
    'general.cancel': 'Batal',
    'general.search': 'Cari',
    'general.noResults': 'Tidak ada hasil',
    'general.viewAll': 'Lihat semua',
    'auth.signin': 'Masuk',
    'auth.signout': 'Keluar',
    'auth.register': 'Buat akun',
    'a11y.skipToContent': 'Langsung ke konten utama',
    'a11y.menu': 'Menu',
    'a11y.closeMenu': 'Tutup menu',
    'a11y.openMenu': 'Buka menu',
  },
  zh: {
    'nav.dashboard': '仪表板',
    'nav.discover': '探索',
    'nav.mylearning': '我的学习',
    'nav.studio': '工作室',
    'nav.wishlist': '心愿单',
    'nav.profile': '个人资料',
    'nav.settings': '设置',
    'nav.notifications': '通知',
    'dashboard.welcome': '欢迎回来，{name}',
    'dashboard.continue': '继续学习',
    'dashboard.deadlines': '即将到来的截止日期',
    'dashboard.certificates': '最近证书',
    'dashboard.discover': '发现课程',
    'course.enroll': '立即报名',
    'course.continue': '继续',
    'course.completed': '已完成',
    'course.modules': '{count} 个模块',
    'course.progress': '已完成 {percent}%',
    'general.loading': '加载中…',
    'general.error': '出了点问题',
    'general.retry': '重试',
    'general.save': '保存',
    'general.cancel': '取消',
    'general.search': '搜索',
    'general.noResults': '未找到结果',
    'general.viewAll': '查看全部',
    'auth.signin': '登录',
    'auth.signout': '退出',
    'auth.register': '创建账户',
    'a11y.skipToContent': '跳到主要内容',
    'a11y.menu': '菜单',
    'a11y.closeMenu': '关闭菜单',
    'a11y.openMenu': '打开菜单',
  },
};

/**
 * Translate a key with optional interpolation.
 * @param {string} key - dot-notation key (e.g. 'nav.dashboard')
 * @param {object} [params] - interpolation values (e.g. { name: 'Faiz' })
 * @returns {string}
 */
export function t(key, params = {}) {
  const dict = dictionaries[_currentLocale] || dictionaries[DEFAULT_LOCALE];
  let str = dict[key] || dictionaries[DEFAULT_LOCALE][key] || key;
  Object.entries(params).forEach(([k, v]) => {
    str = str.replace(new RegExp(`\\{${k}\\}`, 'g'), v);
  });
  return str;
}

export function setLocale(locale) {
  if (SUPPORTED_LOCALES.includes(locale)) {
    _currentLocale = locale;
    localStorage.setItem('mereka.locale', locale);
    document.documentElement.lang = locale;
    // Dispatch event for reactive updates
    window.dispatchEvent(new CustomEvent('locale-change', { detail: { locale } }));
  }
}

export function getLocale() { return _currentLocale; }
export function getSupportedLocales() { return [...SUPPORTED_LOCALES]; }
