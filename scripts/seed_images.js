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
    acceptedAnswers: ['eiffel', 'eiffel tower', 'paris tower', 'la tour eiffel', 'מגדל אייפל'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Eiffel_Tower_from_the_Champ_de_Mars%2C_Paris_2022.jpg/320px-Eiffel_Tower_from_the_Champ_de_Mars%2C_Paris_2022.jpg',
  },
  {
    id: 'statue-of-liberty',
    name: 'Statue of Liberty',
    answer: 'Statue of Liberty',
    acceptedAnswers: ['liberty', 'statue of liberty', 'פסל החירות'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Southwest_corner_of_Statue_of_Liberty_National_Monument.jpg/320px-Southwest_corner_of_Statue_of_Liberty_National_Monument.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Southwest_corner_of_Statue_of_Liberty_National_Monument.jpg/200px-Southwest_corner_of_Statue_of_Liberty_National_Monument.jpg',
  },
  {
    id: 'big-ben',
    name: 'Big Ben',
    answer: 'Big Ben',
    acceptedAnswers: ['big ben', 'elizabeth tower', 'london clock', 'ביג בן'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/Clock_Tower_-_Palace_of_Westminster%2C_London_-_September_2006.jpg/320px-Clock_Tower_-_Palace_of_Westminster%2C_London_-_September_2006.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/Clock_Tower_-_Palace_of_Westminster%2C_London_-_September_2006.jpg/200px-Clock_Tower_-_Palace_of_Westminster%2C_London_-_September_2006.jpg',
  },
  {
    id: 'colosseum',
    name: 'Colosseum',
    answer: 'Colosseum',
    acceptedAnswers: ['colosseum', 'coliseum', 'rome', 'קולוסיאום'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/Colosseo_2020.jpg/320px-Colosseo_2020.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/Colosseo_2020.jpg/200px-Colosseo_2020.jpg',
  },
  {
    id: 'taj-mahal',
    name: 'Taj Mahal',
    answer: 'Taj Mahal',
    acceptedAnswers: ['taj mahal', 'tajmahal', 'taj', 'טאג' מאהל'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Taj_Mahal_%28Edited%29.jpeg/320px-Taj_Mahal_%28Edited%29.jpeg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Taj_Mahal_%28Edited%29.jpeg/200px-Taj_Mahal_%28Edited%29.jpeg',
  },
  {
    id: 'great-wall',
    name: 'Great Wall of China',
    answer: 'Great Wall of China',
    acceptedAnswers: ['great wall', 'great wall of china', 'החומה הסינית'],
    category: 'landmark',
    isPremium: false,
    cost: 0,
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/The_Great_Wall_of_China_at_Jinshanling-edit.jpg/320px-The_Great_Wall_of_China_at_Jinshanling-edit.jpg',
    thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/The_Great_Wall_of_China_at_Jinshanling-edit.jpg/200px-The_Great_Wall_of_China_at_Jinshanling-edit.jpg',
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
