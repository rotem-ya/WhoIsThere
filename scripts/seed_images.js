const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const images = [
  // ──── מקומות בעולם ────
  {
    id: 'eiffel-tower',
    name: 'מגדל אייפל',
    answer: 'מגדל אייפל',
    acceptedAnswers: ['מגדל אייפל', 'אייפל', 'eiffel', 'eiffel tower', 'paris', 'פריז'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=400&q=80',
  },
  {
    id: 'statue-of-liberty',
    name: 'פסל החירות',
    answer: 'פסל החירות',
    acceptedAnswers: ['פסל החירות', 'liberty', 'statue of liberty', 'ניו יורק', 'new york'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=400&q=80',
  },
  {
    id: 'colosseum',
    name: 'קולוסיאום',
    answer: 'קולוסיאום',
    acceptedAnswers: ['קולוסיאום', 'colosseum', 'coliseum', 'רומא', 'rome'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400&q=80',
  },
  {
    id: 'taj-mahal',
    name: 'טאג׳ מאהל',
    answer: 'טאג׳ מאהל',
    acceptedAnswers: ['טאג מאהל', 'טאג׳ מאהל', 'taj mahal', 'taj', 'הודו', 'india'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=400&q=80',
  },
  {
    id: 'great-wall',
    name: 'החומה הסינית',
    answer: 'החומה הסינית',
    acceptedAnswers: ['חומה סינית', 'החומה הסינית', 'great wall', 'great wall of china', 'סין', 'china'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&q=80',
  },
  {
    id: 'big-ben',
    name: 'ביג בן',
    answer: 'ביג בן',
    acceptedAnswers: ['ביג בן', 'big ben', 'לונדון', 'london', 'elizabeth tower'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=80',
  },

  // ──── מקומות בישראל ────
  {
    id: 'kotel',
    name: 'הכותל המערבי',
    answer: 'הכותל המערבי',
    acceptedAnswers: ['כותל', 'הכותל', 'הכותל המערבי', 'kotel', 'western wall', 'wailing wall', 'ירושלים'],
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Western_Wall_in_Jerusalem.jpg/800px-Western_Wall_in_Jerusalem.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Western_Wall_in_Jerusalem.jpg/400px-Western_Wall_in_Jerusalem.jpg',
  },
  {
    id: 'masada',
    name: 'מצדה',
    answer: 'מצדה',
    acceptedAnswers: ['מצדה', 'masada', 'מצד'],
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/Masada_on_a_clear_day.jpg/800px-Masada_on_a_clear_day.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/Masada_on_a_clear_day.jpg/400px-Masada_on_a_clear_day.jpg',
  },
  {
    id: 'dead-sea',
    name: 'ים המלח',
    answer: 'ים המלח',
    acceptedAnswers: ['ים המלח', 'dead sea', 'ים מלח', 'dead-sea'],
    category: 'israeliLandmark',
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
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Bahai_gardens_Haifa_aerial_view.jpg/800px-Bahai_gardens_Haifa_aerial_view.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Bahai_gardens_Haifa_aerial_view.jpg/400px-Bahai_gardens_Haifa_aerial_view.jpg',
  },
  {
    id: 'dome-of-rock',
    name: 'כיפת הסלע',
    answer: 'כיפת הסלע',
    acceptedAnswers: ['כיפת הסלע', 'dome of the rock', 'כיפה', 'ירושלים', 'jerusalem'],
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Dome_of_the_rock_w_sign.jpg/800px-Dome_of_the_rock_w_sign.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Dome_of_the_rock_w_sign.jpg/400px-Dome_of_the_rock_w_sign.jpg',
  },
  {
    id: 'ramon-crater',
    name: 'מכתש רמון',
    answer: 'מכתש רמון',
    acceptedAnswers: ['מכתש רמון', 'ramon crater', 'מכתש', 'נגב', 'negev', 'רמון'],
    category: 'israeliLandmark',
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
    category: 'israeliLandmark',
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
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Old_City_Acre_aerial_view.jpg/800px-Old_City_Acre_aerial_view.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Old_City_Acre_aerial_view.jpg/400px-Old_City_Acre_aerial_view.jpg',
  },
  {
    id: 'tel-aviv',
    name: 'תל אביב',
    answer: 'תל אביב',
    acceptedAnswers: ['תל אביב', 'tel aviv', 'תל-אביב', 'tlv'],
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Tel_Aviv_Skyline_from_Jaffa.jpg/800px-Tel_Aviv_Skyline_from_Jaffa.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Tel_Aviv_Skyline_from_Jaffa.jpg/400px-Tel_Aviv_Skyline_from_Jaffa.jpg',
  },
  {
    id: 'kinneret',
    name: 'כינרת',
    answer: 'כינרת',
    acceptedAnswers: ['כינרת', 'ים כינרת', 'sea of galilee', 'lake tiberias', 'כנרת', 'טבריה'],
    category: 'israeliLandmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Sea_of_Galilee_at_sunrise.jpg/800px-Sea_of_Galilee_at_sunrise.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Sea_of_Galilee_at_sunrise.jpg/400px-Sea_of_Galilee_at_sunrise.jpg',
  },
];

async function seed() {
  console.log('Seeding images...');
  const batch = db.batch();

  for (const image of images) {
    const { id, ...data } = image;
    const ref = db.collection('images').doc(id);
    batch.set(ref, data);
    console.log(`  + [${image.category}] ${image.name}`);
  }

  await batch.commit();
  console.log(`\nDone! Added ${images.length} images.`);
  console.log(`  ${images.filter(i => i.category === 'landmark').length} מקומות בעולם`);
  console.log(`  ${images.filter(i => i.category === 'israeliLandmark').length} מקומות בישראל`);
  process.exit(0);
}

seed().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
