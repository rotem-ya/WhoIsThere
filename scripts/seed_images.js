const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const images = [
  {
    id: 'eiffel-tower',
    name: 'Eiffel Tower',
    answer: 'Eiffel Tower',
    acceptedAnswers: ['eiffel', 'eiffel tower', 'paris tower', 'מגדל אייפל'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1431274172761-fca41d930114?w=300&q=80',
  },
  {
    id: 'statue-of-liberty',
    name: 'Statue of Liberty',
    answer: 'Statue of Liberty',
    acceptedAnswers: ['liberty', 'statue of liberty', 'פסל החירות'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=300&q=80',
  },
  {
    id: 'big-ben',
    name: 'Big Ben',
    answer: 'Big Ben',
    acceptedAnswers: ['big ben', 'elizabeth tower', 'london clock', 'ביג בן'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=300&q=80',
  },
  {
    id: 'colosseum',
    name: 'Colosseum',
    answer: 'Colosseum',
    acceptedAnswers: ['colosseum', 'coliseum', 'rome', 'קולוסיאום'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=300&q=80',
  },
  {
    id: 'taj-mahal',
    name: 'Taj Mahal',
    answer: 'Taj Mahal',
    acceptedAnswers: ['taj mahal', 'tajmahal', 'taj', 'טאג מאהל'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=300&q=80',
  },
  {
    id: 'great-wall',
    name: 'Great Wall of China',
    answer: 'Great Wall of China',
    acceptedAnswers: ['great wall', 'great wall of china', 'החומה הסינית'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&q=80',
    thumbnailUrl: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=300&q=80',
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
