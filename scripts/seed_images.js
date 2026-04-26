const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// All images are Israeli landmarks. URLs from Wikimedia Commons.
const images = [
  {
    id: 'kotel',
    name: 'הכותל המערבי',
    answer: 'הכותל המערבי',
    acceptedAnswers: ['כותל', 'הכותל', 'הכותל המערבי', 'kotel', 'western wall', 'wailing wall'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Western_Wall_in_Jerusalem.jpg/800px-Western_Wall_in_Jerusalem.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Western_Wall_in_Jerusalem.jpg/400px-Western_Wall_in_Jerusalem.jpg',
  },
  {
    id: 'masada',
    name: 'מצדה',
    answer: 'מצדה',
    acceptedAnswers: ['מצדה', 'masada'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/Masada_on_a_clear_day.jpg/800px-Masada_on_a_clear_day.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/Masada_on_a_clear_day.jpg/400px-Masada_on_a_clear_day.jpg',
  },
  {
    id: 'dead-sea',
    name: 'ים המלח',
    answer: 'ים המלח',
    acceptedAnswers: ['ים המלח', 'dead sea', 'ים מלח'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/Dead_Sea_by_David_Shankbone.jpg/800px-Dead_Sea_by_David_Shankbone.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/Dead_Sea_by_David_Shankbone.jpg/400px-Dead_Sea_by_David_Shankbone.jpg',
  },
  {
    id: 'bahai-gardens',
    name: 'גני בהאי',
    answer: 'גני בהאי',
    acceptedAnswers: ['גני בהאי', 'בהאי', 'bahai', 'bahai gardens', 'חיפה', 'haifa'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Bahai_gardens_Haifa_aerial_view.jpg/800px-Bahai_gardens_Haifa_aerial_view.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Bahai_gardens_Haifa_aerial_view.jpg/400px-Bahai_gardens_Haifa_aerial_view.jpg',
  },
  {
    id: 'dome-of-rock',
    name: 'כיפת הסלע',
    answer: 'כיפת הסלע',
    acceptedAnswers: ['כיפת הסלע', 'dome of the rock', 'כיפה', 'ירושלים'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Dome_of_the_rock_w_sign.jpg/800px-Dome_of_the_rock_w_sign.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Dome_of_the_rock_w_sign.jpg/400px-Dome_of_the_rock_w_sign.jpg',
  },
  {
    id: 'ramon-crater',
    name: 'מכתש רמון',
    answer: 'מכתש רמון',
    acceptedAnswers: ['מכתש רמון', 'ramon crater', 'מכתש', 'נגב', 'negev'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Makhtesh_Ramon_Crater_Panorama.jpg/800px-Makhtesh_Ramon_Crater_Panorama.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Makhtesh_Ramon_Crater_Panorama.jpg/400px-Makhtesh_Ramon_Crater_Panorama.jpg',
  },
  {
    id: 'caesarea',
    name: 'קיסריה',
    answer: 'קיסריה',
    acceptedAnswers: ['קיסריה', 'caesarea', 'קיסרייה'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Caesarea_Maritima_aerial_view.jpg/800px-Caesarea_Maritima_aerial_view.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Caesarea_Maritima_aerial_view.jpg/400px-Caesarea_Maritima_aerial_view.jpg',
  },
  {
    id: 'akko',
    name: 'עכו',
    answer: 'עכו',
    acceptedAnswers: ['עכו', 'עכא', 'akko', 'acre', 'akka'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Old_City_Acre_aerial_view.jpg/800px-Old_City_Acre_aerial_view.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Old_City_Acre_aerial_view.jpg/400px-Old_City_Acre_aerial_view.jpg',
  },
  {
    id: 'tel-aviv-skyline',
    name: 'תל אביב',
    answer: 'תל אביב',
    acceptedAnswers: ['תל אביב', 'tel aviv', 'תל-אביב'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Tel_Aviv_Skyline_from_Jaffa.jpg/800px-Tel_Aviv_Skyline_from_Jaffa.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Tel_Aviv_Skyline_from_Jaffa.jpg/400px-Tel_Aviv_Skyline_from_Jaffa.jpg',
  },
  {
    id: 'sea-of-galilee',
    name: 'כינרת',
    answer: 'כינרת',
    acceptedAnswers: ['כינרת', 'ים כינרת', 'sea of galilee', 'lake tiberias', 'כנרת', 'כינרת'],
    category: 'place',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Sea_of_Galilee_at_sunrise.jpg/800px-Sea_of_Galilee_at_sunrise.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Sea_of_Galilee_at_sunrise.jpg/400px-Sea_of_Galilee_at_sunrise.jpg',
  },
];

async function seed() {
  console.log('Seeding Israeli landmark images...');
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
