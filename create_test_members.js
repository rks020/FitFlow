import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://hrywsorgjitwedsnlbyp.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyeXdzb3Jnaml0d2Vkc25sYnlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NTgwNzIsImV4cCI6MjA1MDUzNDA3Mn0.qN8wPTgFudFWD98kX9BbEp_V_8TLZWLMVIlCPfWKnJk';

const supabase = createClient(supabaseUrl, supabaseKey);

const members = [
    { firstName: 'Ahmet', lastName: 'Yılmaz', age: 21 },
    { firstName: 'Mehmet', lastName: 'Demir', age: 22 },
    { firstName: 'Ayşe', lastName: 'Kaya', age: 23 },
    { firstName: 'Fatma', lastName: 'Çelik', age: 24 },
    { firstName: 'Ali', lastName: 'Şahin', age: 25 },
    { firstName: 'Zeynep', lastName: 'Arslan', age: 26 },
    { firstName: 'Mustafa', lastName: 'Koç', age: 27 },
    { firstName: 'Elif', lastName: 'Aydın', age: 28 },
    { firstName: 'Can', lastName: 'Taş', age: 29 },
    { firstName: 'Selin', lastName: 'Kurt', age: 30 }
];

async function createMembers() {
    const orgId = 'fbbf54d7-ba37-49e5-947f-8907d4895b24';

    for (let i = 0; i < members.length; i++) {
        const member = members[i];
        const email = `test.member${i + 1}@fitflow.test`;

        try {
            // Call create-member edge function
            const { data, error } = await supabase.functions.invoke('create-member', {
                body: {
                    email: email,
                    first_name: member.firstName,
                    last_name: member.lastName,
                    age: member.age,
                    hobbies: 'Spor, Fitness',
                    organization_id: orgId
                }
            });

            if (error) {
                console.error(`Error creating ${member.firstName}:`, error);
            } else {
                console.log(`Created: ${member.firstName} ${member.lastName}`);
            }
        } catch (err) {
            console.error(`Exception for ${member.firstName}:`, err);
        }
    }

    console.log('Done!');
}

createMembers();
