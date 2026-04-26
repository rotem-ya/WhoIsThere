const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const images = [
  // ──── אתרים ישראלים ────
  {
    id: 'kotel',
    name: 'הכותל המערבי',
    answer: 'הכותל המערבי',
    acceptedAnswers: ['כותל', 'הכותל', 'הכותל המערבי', 'kotel', 'western wall', 'wailing wall'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1552423314-cf29ab68ad73?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1552423314-cf29ab68ad73?w=300&q=80',
  },
  {
    id: 'masada',
    name: 'מצדה',
    answer: 'מצדה',
    acceptedAnswers: ['מצדה', 'masada'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=300&q=80',
  },
  {
    id: 'dead-sea',
    name: 'ים המלח',
    answer: 'ים המלח',
    acceptedAnswers: ['ים המלח', 'dead sea', 'ים מלח'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=300&q=80',
  },
  {
    id: 'tel-aviv',
    name: 'תל אביב',
    answer: 'תל אביב',
    acceptedAnswers: ['תל אביב', 'tel aviv', 'תל-אביב'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1565552645632-d725f8bfc19a?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1565552645632-d725f8bfc19a?w=300&q=80',
  },
  {
    id: 'kinneret',
    name: 'כינרת',
    answer: 'כינרת',
    acceptedAnswers: ['כינרת', 'ים כינרת', 'sea of galilee', 'lake tiberias', 'כנרת'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1544551763-77ef2d0cfc6c?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1544551763-77ef2d0cfc6c?w=300&q=80',
  },
  {
    id: 'bahai-gardens',
    name: 'גני בהאי',
    answer: 'גני בהאי',
    acceptedAnswers: ['גני בהאי', 'בהאי', 'bahai', 'bahai gardens', 'חיפה', 'haifa'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1529973625058-a665431328fb?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1529973625058-a665431328fb?w=300&q=80',
  },
  {
    id: 'jerusalem-old-city',
    name: 'העיר העתיקה - ירושלים',
    answer: 'ירושלים',
    acceptedAnswers: ['ירושלים', 'jerusalem', 'עיר עתיקה', 'old city'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=300&q=80',
  },
  {
    id: 'dome-of-rock',
    name: 'כיפת הסלע',
    answer: 'כיפת הסלע',
    acceptedAnswers: ['כיפת הסלע', 'dome of the rock', 'כיפה', 'ירושלים'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1547471080-7cc2caa01a7e?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1547471080-7cc2caa01a7e?w=300&q=80',
  },
  {
    id: 'negev-desert',
    name: 'מדבר הנגב',
    answer: 'נגב',
    acceptedAnswers: ['נגב', 'מדבר הנגב', 'negev', 'negev desert'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1540979388789-6cee28a1cdc9?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1540979388789-6cee28a1cdc9?w=300&q=80',
  },
  {
    id: 'caesarea',
    name: 'קיסריה',
    answer: 'קיסריה',
    acceptedAnswers: ['קיסריה', 'caesarea', 'קיסרייה'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1589308078055-0b27a7e8b02f?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1589308078055-0b27a7e8b02f?w=300&q=80',
  },

  // ──── חבילת פרמיום: ידוענים ישראלים ────
  {
    id: 'gal-gadot',
    name: 'גל גדות',
    answer: 'גל גדות',
    acceptedAnswers: ['גל גדות', 'gal gadot', 'גדות', 'gadot'],
    category: 'actor',
    isPremium: true,
    cost: 50,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Gal_Gadot_at_the_2021_Met_Gala.jpg/800px-Gal_Gadot_at_the_2021_Met_Gala.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Gal_Gadot_at_the_2021_Met_Gala.jpg/300px-Gal_Gadot_at_the_2021_Met_Gala.jpg',
  },
  {
    id: 'noa-kirel',
    name: 'נועה קירל',
    answer: 'נועה קירל',
    acceptedAnswers: ['נועה קירל', 'noa kirel', 'קירל', 'נועה'],
    category: 'singer',
    isPremium: true,
    cost: 50,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Noa_Kirel_-_Eurovision_2023_-_Israel.jpg/800px-Noa_Kirel_-_Eurovision_2023_-_Israel.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Noa_Kirel_-_Eurovision_2023_-_Israel.jpg/300px-Noa_Kirel_-_Eurovision_2023_-_Israel.jpg',
  },
];

async function seed() {
  console.log('Seeding images...');
  const batch = db.batch();

  for (const image of images) {
    const { id, ...data } = image;
    const ref = db.collection('images').doc(id);
    batch.set(ref, data);
    console.log(`  + ${image.name}`);
  }

  await batch.commit();
  console.log(`Done! Added ${images.length} images.`);
  process.exit(0);
}

seed().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
