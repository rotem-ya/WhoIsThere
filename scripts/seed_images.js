const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const images = [
  // ──── מקומות בעולם (category: 'landmark') ────
  {
    id: 'eiffel-tower',
    name: 'מגדל אייפל',
    answer: 'מגדל אייפל',
    acceptedAnswers: ['מגדל אייפל', 'אייפל', 'eiffel', 'eiffel tower', 'paris'],
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
    acceptedAnswers: ['פסל החירות', 'liberty', 'statue of liberty', 'ניו יורק'],
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
    acceptedAnswers: ['טאג מאהל', 'טאג׳ מאהל', 'taj mahal', 'taj'],
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
    acceptedAnswers: ['חומה סינית', 'החומה הסינית', 'great wall', 'great wall of china', 'סין'],
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
    acceptedAnswers: ['ביג בן', 'big ben', 'לונדון', 'london'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=80',
  },

  // ──── מקומות בישראל (category: 'israeliLandmark') ────
  // ** ממתין לאישור רשימה — יתווסף לאחר מכן **
];

async function seed() {
  console.log('Seeding images...');
  const batch = db.batch();

  for (const image of images) {
    const { id, ...data } = image;
    const ref = db.collection('images').doc(id);
    batch.set(ref, data);
    console.log(`  + ${image.name} [${image.category}]`);
  }

  await batch.commit();
  console.log(`Done! Added ${images.length} images.`);
  process.exit(0);
}

seed().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
