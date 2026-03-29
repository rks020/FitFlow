import { supabaseClient } from '../supabase-config.js';
import { showToast, turkishToLower } from '../utils.js';

let currentTab = 'programs'; // programs or exercises
let exercises = [];
let workoutPrograms = [];
let selectedExercisesForWorkout = [];
let editingWorkoutId = null;

export async function loadWorkouts() {
    const contentArea = document.getElementById('content-area');
    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Antrenman Yönetimi</h2>
            <div id="workouts-actions"></div>
        </div>

        <div class="workout-tabs">
            <button class="tab-btn ${currentTab === 'programs' ? 'active' : ''}" data-tab="programs">Programlar</button>
            <button class="tab-btn ${currentTab === 'exercises' ? 'active' : ''}" data-tab="exercises">Hareketler</button>
        </div>

        <div class="search-bar">
            <input type="text" id="workout-search" placeholder="Ara...">
        </div>

        <div id="workouts-content">
            <p style="text-align: center; padding: 40px; color: #888;">Yükleniyor...</p>
        </div>
    `;

    setupTabListeners();
    setupSearchListener();
    renderActiveTab();
    setupModalListeners();
}

function setupTabListeners() {
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            currentTab = e.target.getAttribute('data-tab');
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            e.target.classList.add('active');
            renderActiveTab();
        });
    });
}

function setupSearchListener() {
    const searchInput = document.getElementById('workout-search');
    searchInput.addEventListener('input', () => {
        const query = turkishToLower(searchInput.value.trim());
        if (currentTab === 'programs') {
            renderPrograms(workoutPrograms.filter(p => turkishToLower(p.name).includes(query)));
        } else {
            renderExercises(exercises.filter(e => turkishToLower(e.name).includes(query)));
        }
    });
}

function renderActiveTab() {
    const actionsContainer = document.getElementById('workouts-actions');
    const contentContainer = document.getElementById('workouts-content');

    if (currentTab === 'programs') {
        actionsContainer.innerHTML = '<button class="btn btn-primary" id="add-workout-btn">+ Yeni Program</button>';
        document.getElementById('add-workout-btn').onclick = () => openCreateWorkoutModal();
        loadProgramsList();
    } else {
        actionsContainer.innerHTML = '<button class="btn btn-primary" id="add-exercise-btn">+ Yeni Hareket</button>';
        document.getElementById('add-exercise-btn').onclick = () => openCreateExerciseModal();
        loadExercisesList();
    }
}

// --- Exercise Management ---

async function loadExercisesList() {
    const contentContainer = document.getElementById('workouts-content');
    contentContainer.innerHTML = '<p style="text-align: center; padding: 40px; color: #888;">Hareketler yükleniyor...</p>';

    try {
        const { data, error } = await supabaseClient
            .from('exercises')
            .select('*')
            .order('name');

        if (error) throw error;
        exercises = data;
        renderExercises(data);
    } catch (err) {
        console.error('Error loading exercises:', err);
        showToast('Hareketler yüklenirken bir hata oluştu.', 'error');
    }
}

function renderExercises(data) {
    const container = document.getElementById('workouts-content');
    if (!data.length) {
        container.innerHTML = '<div style="text-align: center; padding: 40px; color: #888;">Hareket bulunamadı.</div>';
        return;
    }

    container.innerHTML = `
        <div class="exercise-grid">
            ${data.map(ex => `
                <div class="exercise-card">
                    <div class="exercise-icon">💪</div>
                    <div class="exercise-info">
                        <h4>${ex.name}</h4>
                        <p>${ex.target_muscle}</p>
                    </div>
                    <div style="margin-top: 15px; display: flex; gap: 8px;">
                        ${ex.video_url ? `<a href="${ex.video_url}" target="_blank" class="btn btn-small btn-secondary" style="text-decoration:none; text-align:center;">Video</a>` : ''}
                        <button class="btn btn-small btn-danger delete-exercise" data-id="${ex.id}">Sil</button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;

    // Setup delete listeners
    document.querySelectorAll('.delete-exercise').forEach(btn => {
        btn.onclick = (e) => {
            const id = e.target.getAttribute('data-id');
            const name = data.find(x => x.id === id).name;
            confirmDeleteExercise(id, name);
        };
    });
}

function openCreateExerciseModal() {
    document.getElementById('create-exercise-modal').classList.add('active');
}

function setupModalListeners() {
    // Exercise Modal
    const exerciseModal = document.getElementById('create-exercise-modal');
    document.getElementById('close-create-exercise-modal').onclick = () => exerciseModal.classList.remove('active');
    
    document.getElementById('create-exercise-form').onsubmit = async (e) => {
        e.preventDefault();
        const name = document.getElementById('exercise-name').value.trim();
        const target = document.getElementById('exercise-target').value;
        const video = document.getElementById('exercise-video').value.trim();

        try {
            const { data: { user } } = await supabaseClient.auth.getUser();
            const { data: profile } = await supabaseClient.from('profiles').select('organization_id').eq('id', user.id).single();

            const { error } = await supabaseClient.from('exercises').insert({
                name,
                target_muscle: target,
                video_url: video,
                organization_id: profile.organization_id,
                created_by: user.id
            });

            if (error) throw error;
            showToast('Hareket başarıyla eklendi.', 'success');
            exerciseModal.classList.remove('active');
            document.getElementById('create-exercise-form').reset();
            loadExercisesList();
        } catch (err) {
            console.error('Error creating exercise:', err);
            showToast('Hata: ' + err.message, 'error');
        }
    };

    // Workout Modal
    const workoutModal = document.getElementById('create-workout-modal');
    document.getElementById('close-create-workout-modal').onclick = () => workoutModal.classList.remove('active');

    document.getElementById('create-workout-form').onsubmit = handleSaveWorkout;

    // Selector Modal
    const selectorModal = document.getElementById('exercise-selector-modal');
    document.getElementById('close-exercise-selector-modal').onclick = () => selectorModal.classList.remove('active');
    document.getElementById('open-exercise-selector-btn').onclick = openExerciseSelector;
}

function confirmDeleteExercise(id, name) {
    const modal = document.getElementById('confirm-modal');
    document.getElementById('confirm-title').innerText = 'Hareketi Sil?';
    document.getElementById('confirm-message').innerText = `"${name}" isimli hareketi silmek istediğinize emin misiniz? Bu hareket kullanılan programlardan da kaldırılacaktır.`;
    
    modal.classList.add('active');

    document.getElementById('confirm-cancel').onclick = () => modal.classList.remove('active');
    document.getElementById('confirm-yes').onclick = async () => {
        try {
            const { error } = await supabaseClient.from('exercises').delete().eq('id', id);
            if (error) throw error;
            showToast('Hareket silindi.', 'success');
            modal.classList.remove('active');
            loadExercisesList();
        } catch (err) {
            showToast('Silme hatası: ' + err.message, 'error');
        }
    };
}

// --- Workout Program Management ---

async function loadProgramsList() {
    const container = document.getElementById('workouts-content');
    container.innerHTML = '<p style="text-align: center; padding: 40px; color: #888;">Programlar yükleniyor...</p>';

    try {
        const { data, error } = await supabaseClient
            .from('workouts')
            .select(`
                *,
                workout_exercises (
                    id, order_index, sets, reps, rest_seconds,
                    exercises (id, name, target_muscle)
                )
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;
        workoutPrograms = data;
        renderPrograms(data);
    } catch (err) {
        console.error('Error loading workouts:', err);
        showToast('Programlar yüklenemedi.', 'error');
    }
}

function renderPrograms(data) {
    const container = document.getElementById('workouts-content');
    if (!data.length) {
        container.innerHTML = '<div style="text-align: center; padding: 40px; color: #888;">Henüz program oluşturulmamış.</div>';
        return;
    }

    container.innerHTML = `
        <div class="workout-grid">
            ${data.map(w => {
                // Get exercise names as a summary string
                const sortedExercises = [...(w.workout_exercises || [])].sort((a, b) => a.order_index - b.order_index);
                const exerciseSummary = sortedExercises.map(ex => ex.exercises?.name).filter(Boolean).join(', ') || 'Hareket eklenmemiş';

                return `
                <div class="workout-card clickable-card" data-id="${w.id}">
                    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 15px;">
                        <h4 style="font-size: 18px; margin: 0;">${w.name}</h4>
                        <span class="exercise-count-tag">${w.workout_exercises?.length || 0} Hareket</span>
                    </div>
                    <p style="font-size: 14px; color: #ccc; margin-bottom: 20px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">
                        ${exerciseSummary}
                    </p>
                    <div style="display: flex; gap: 8px;">
                        <button class="btn btn-small btn-danger delete-workout" data-id="${w.id}">Sil</button>
                    </div>
                </div>
                `;
            }).join('')}
        </div>
    `;

    // Listen for entire card click for edit
    document.querySelectorAll('.workout-card').forEach(card => {
        card.onclick = (e) => {
            // If delete button was clicked, don't trigger edit
            if (e.target.classList.contains('delete-workout')) return;
            
            const id = card.getAttribute('data-id');
            const workout = workoutPrograms.find(p => p.id === id);
            openEditWorkoutModal(workout);
        };
    });

    document.querySelectorAll('.delete-workout').forEach(btn => {
        btn.onclick = (e) => {
            e.stopPropagation(); // Precaution
            const id = e.target.getAttribute('data-id');
            const name = data.find(x => x.id === id).name;
            confirmDeleteWorkout(id, name);
        };
    });
}

function openCreateWorkoutModal() {
    editingWorkoutId = null;
    selectedExercisesForWorkout = [];
    
    document.getElementById('workout-modal-title').innerText = 'Yeni Program Oluştur';
    document.getElementById('save-workout-btn').innerText = 'PROGRAMI KAYDET';
    
    document.getElementById('create-workout-form').reset();
    renderWorkoutBuilderList();
    document.getElementById('create-workout-modal').classList.add('active');
}

function openEditWorkoutModal(workout) {
    editingWorkoutId = workout.id;
    
    document.getElementById('workout-modal-title').innerText = 'Programı Düzenle';
    document.getElementById('save-workout-btn').innerText = 'GÜNCELLEMEYİ KAYDET';
    
    document.getElementById('workout-name').value = workout.name;
    document.getElementById('workout-description').value = workout.description || '';
    
    // Convert DB exercises to our selection state
    const sorted = [...(workout.workout_exercises || [])].sort((a, b) => a.order_index - b.order_index);
    selectedExercisesForWorkout = sorted.map(we => ({
        id: we.exercises.id,
        name: we.exercises.name,
        target_muscle: we.exercises.target_muscle,
        sets: we.sets,
        reps: we.reps,
        rest: we.rest_seconds
    }));
    
    renderWorkoutBuilderList();
    document.getElementById('create-workout-modal').classList.add('active');
}

function openExerciseSelector() {
    const selectorList = document.getElementById('selector-list');
    const searchInput = document.getElementById('selector-search');
    
    const renderList = (filtered) => {
        selectorList.innerHTML = filtered.map(ex => `
            <div class="selector-item" data-id="${ex.id}">
                <h4>${ex.name}</h4>
                <p>${ex.target_muscle}</p>
            </div>
        `).join('');

        document.querySelectorAll('.selector-item').forEach(item => {
            item.onclick = () => {
                const id = item.getAttribute('data-id');
                addExerciseToWorkout(id);
                document.getElementById('exercise-selector-modal').classList.remove('active');
            };
        });
    };

    renderList(exercises);
    
    searchInput.oninput = () => {
        const query = turkishToLower(searchInput.value.trim());
        renderList(exercises.filter(ex => turkishToLower(ex.name).includes(query)));
    };

    document.getElementById('exercise-selector-modal').classList.add('active');
}

function addExerciseToWorkout(id) {
    const ex = exercises.find(x => x.id === id);
    if (!ex) return;

    selectedExercisesForWorkout.push({
        id: ex.id,
        name: ex.name,
        target_muscle: ex.target_muscle,
        sets: 3,
        reps: '12',
        rest: 60
    });
    renderWorkoutBuilderList();
}

function renderWorkoutBuilderList() {
    const list = document.getElementById('workout-builder-list');
    if (!selectedExercisesForWorkout.length) {
        list.innerHTML = '<div style="text-align: center; padding: 30px; background: rgba(255,255,255,0.02); border-radius: 12px; border: 1px dashed rgba(255,255,255,0.1); color: #666;">Henüz hareket eklenmedi</div>';
        return;
    }

    list.innerHTML = selectedExercisesForWorkout.map((ex, index) => `
        <div class="builder-item">
            <div class="builder-item-header">
                <span style="font-weight: 600;">${index + 1}. ${ex.name}</span>
                <button type="button" class="remove-exercise-btn" data-index="${index}" style="background: rgba(239, 68, 68, 0.1); color: #ef4444; border: none; width: 24px; height: 24px; border-radius: 6px; cursor: pointer;">&times;</button>
            </div>
            <div class="builder-item-inputs">
                <div class="builder-input-group">
                    <label>Set</label>
                    <input type="number" class="set-input" data-index="${index}" value="${ex.sets}">
                </div>
                <div class="builder-input-group">
                    <label>Tekrar</label>
                    <input type="text" class="rep-input" data-index="${index}" value="${ex.reps}">
                </div>
                <div class="builder-input-group">
                    <label>Dinlenme (sn)</label>
                    <input type="number" class="rest-input" data-index="${index}" value="${ex.rest}">
                </div>
            </div>
        </div>
    `).join('');

    // Setup remove listeners
    document.querySelectorAll('.remove-exercise-btn').forEach(btn => {
        btn.onclick = () => {
            const index = parseInt(btn.getAttribute('data-index'));
            selectedExercisesForWorkout.splice(index, 1);
            renderWorkoutBuilderList();
        };
    });

    // Sync input changes
    list.querySelectorAll('input').forEach(input => {
        input.onchange = (e) => {
            const index = parseInt(e.target.getAttribute('data-index'));
            const field = e.target.classList.contains('set-input') ? 'sets' : 
                          e.target.classList.contains('rep-input') ? 'reps' : 'rest';
            selectedExercisesForWorkout[index][field] = e.target.value;
        };
    });
}

async function handleSaveWorkout(e) {
    e.preventDefault();
    if (!selectedExercisesForWorkout.length) {
        showToast('En az bir hareket eklemelisiniz.', 'error');
        return;
    }

    const name = document.getElementById('workout-name').value.trim();
    const description = document.getElementById('workout-description').value.trim();

    try {
        const { data: { user } } = await supabaseClient.auth.getUser();
        
        let workoutId;
        
        if (editingWorkoutId) {
            // UPDATE mode
            const { error } = await supabaseClient
                .from('workouts')
                .update({ name, description })
                .eq('id', editingWorkoutId);
            
            if (error) throw error;
            workoutId = editingWorkoutId;
            
            // Sync exercises: delete all and re-insert
            const { error: delError } = await supabaseClient
                .from('workout_exercises')
                .delete()
                .eq('workout_id', workoutId);
            
            if (delError) throw delError;
        } else {
            // INSERT mode
            const { data: profile } = await supabaseClient.from('profiles').select('organization_id').eq('id', user.id).single();

            const { data: workout, error: wError } = await supabaseClient
                .from('workouts')
                .insert({
                    name,
                    description,
                    organization_id: profile.organization_id,
                    created_by: user.id
                })
                .select()
                .single();

            if (wError) throw wError;
            workoutId = workout.id;
        }

        // 2. Insert Exercises (for both modes post-delete or post-insert)
        const workoutExercises = selectedExercisesForWorkout.map((ex, index) => ({
            workout_id: workoutId,
            exercise_id: ex.id,
            order_index: index,
            sets: parseInt(ex.sets),
            reps: ex.reps.toString(),
            rest_seconds: parseInt(ex.rest)
        }));

        const { error: exError } = await supabaseClient
            .from('workout_exercises')
            .insert(workoutExercises);

        if (exError) throw exError;

        showToast(editingWorkoutId ? 'Program güncellendi.' : 'Program kaydedildi.', 'success');
        document.getElementById('create-workout-modal').classList.remove('active');
        loadProgramsList();
        editingWorkoutId = null;
    } catch (err) {
        console.error('Error saving workout:', err);
        showToast('Hata: ' + err.message, 'error');
    }
}

function confirmDeleteWorkout(id, name) {
    const modal = document.getElementById('confirm-modal');
    document.getElementById('confirm-title').innerText = 'Programı Sil?';
    document.getElementById('confirm-message').innerText = `"${name}" programını silmek üzeresiniz. Bu işlem geri alınamaz.`;
    
    modal.classList.add('active');

    document.getElementById('confirm-cancel').onclick = () => modal.classList.remove('active');
    document.getElementById('confirm-yes').onclick = async () => {
        try {
            const { error } = await supabaseClient.from('workouts').delete().eq('id', id);
            if (error) throw error;
            showToast('Program silindi.', 'success');
            modal.classList.remove('active');
            loadProgramsList();
        } catch (err) {
            showToast('Silme hatası: ' + err.message, 'error');
        }
    };
}
