const API_BASE = 'http://localhost:8000/api';
let currentTeacherId = 1; // Assuming seeded teacher ID is 1
let currentClassId = null;
let studentsData = [];

// Initialize Date
document.getElementById('current-date').textContent = new Date().toLocaleDateString('en-US', { 
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' 
});

// Format today's date to YYYY-MM-DD for the API payload
const todayISO = new Date().toISOString().split('T')[0];

document.addEventListener('DOMContentLoaded', async () => {
    // Set default date to today
    const dateSelect = document.getElementById('date-select');
    dateSelect.value = todayISO;

    await fetchClasses();
    
    document.getElementById('class-select').addEventListener('change', (e) => {
        currentClassId = e.target.value;
        if (currentClassId) {
            fetchStudents(currentClassId);
        }
    });

    dateSelect.addEventListener('change', () => {
        if (currentClassId) {
            fetchStudents(currentClassId);
        }
    });
});

async function fetchClasses() {
    try {
        const response = await fetch(`${API_BASE}/teachers/${currentTeacherId}/classes`);
        const classes = await response.json();
        
        const select = document.getElementById('class-select');
        select.innerHTML = '<option value="" disabled selected>Select a class...</option>';
        
        classes.forEach(c => {
            const option = document.createElement('option');
            option.value = c.id;
            option.textContent = `${c.class_name}-${c.section} (${c.subject})`;
            select.appendChild(option);
        });
    } catch (error) {
        showToast('Failed to load classes. Is the server running?', 'error');
    }
}

async function fetchStudents(classId) {
    // UI state transitions
    document.getElementById('empty-state').classList.add('hidden');
    document.getElementById('students-container').classList.add('hidden');
    document.getElementById('quick-actions').classList.add('hidden');
    document.getElementById('loading-state').classList.remove('hidden');
    
    try {
        const selectedDate = document.getElementById('date-select').value;
        const response = await fetch(`${API_BASE}/classes/${classId}/students?query_date=${selectedDate}`);
        studentsData = await response.json();
        
        renderStudents();
        
        document.getElementById('loading-state').classList.add('hidden');
        document.getElementById('students-container').classList.remove('hidden');
        document.getElementById('quick-actions').classList.remove('hidden');
    } catch (error) {
        document.getElementById('loading-state').classList.add('hidden');
        showToast('Failed to load students.', 'error');
    }
}

function renderStudents() {
    const tbody = document.getElementById('students-list');
    tbody.innerHTML = '';
    
    studentsData.forEach((item, index) => {
        const tr = document.createElement('tr');
        tr.className = 'hover:bg-gray-50 transition-colors';
        
        // Default to Present if not already marked
        const currentStatus = item.status || 'Present';
        
        tr.innerHTML = `
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">${item.student.roll_no}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">${item.student.name}</td>
            <td class="px-6 py-4 whitespace-nowrap text-center">
                <div class="inline-flex rounded-md shadow-sm" role="group">
                    <input type="radio" name="status-${item.student.id}" id="present-${item.student.id}" value="Present" class="status-radio hidden" ${currentStatus === 'Present' ? 'checked' : ''}>
                    <label for="present-${item.student.id}" class="status-label-present cursor-pointer px-4 py-1.5 text-xs font-medium rounded-l-md border-r border-white/20 transition-colors">
                        Present
                    </label>
                    
                    <input type="radio" name="status-${item.student.id}" id="absent-${item.student.id}" value="Absent" class="status-radio hidden" ${currentStatus === 'Absent' ? 'checked' : ''}>
                    <label for="absent-${item.student.id}" class="status-label-absent cursor-pointer px-4 py-1.5 text-xs font-medium border-r border-white/20 transition-colors">
                        Absent
                    </label>
                    
                    <input type="radio" name="status-${item.student.id}" id="leave-${item.student.id}" value="Leave" class="status-radio hidden" ${currentStatus === 'Leave' ? 'checked' : ''}>
                    <label for="leave-${item.student.id}" class="status-label-leave cursor-pointer px-4 py-1.5 text-xs font-medium rounded-r-md transition-colors">
                        Leave
                    </label>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function markAll(status) {
    const radios = document.querySelectorAll(`input[type="radio"][value="${status}"]`);
    radios.forEach(r => r.checked = true);
}

async function submitAttendance() {
    if (!currentClassId) return;
    
    // Collect data
    const records = [];
    studentsData.forEach(item => {
        const studentId = item.student.id;
        const selectedRadio = document.querySelector(`input[name="status-${studentId}"]:checked`);
        if (selectedRadio) {
            records.push({
                student_id: studentId,
                status: selectedRadio.value
            });
        }
    });
    
    const selectedDate = document.getElementById('date-select').value;
    
    const payload = {
        date: selectedDate,
        class_id: parseInt(currentClassId),
        teacher_id: currentTeacherId,
        records: records
    };
    
    // UI Button state
    const submitBtn = document.getElementById('submit-btn');
    const submitText = document.getElementById('submit-text');
    const submitSpinner = document.getElementById('submit-spinner');
    
    submitBtn.disabled = true;
    submitText.textContent = 'Submitting...';
    submitSpinner.classList.remove('hidden');
    submitBtn.classList.add('opacity-75', 'cursor-not-allowed');
    
    try {
        const response = await fetch(`${API_BASE}/attendance/submit`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });
        
        if (response.ok) {
            showToast('Attendance submitted successfully!', 'success');
        } else {
            const err = await response.json();
            showToast(`Error: ${err.detail || 'Submission failed'}`, 'error');
        }
    } catch (error) {
        showToast('Network error while submitting attendance.', 'error');
    } finally {
        submitBtn.disabled = false;
        submitText.textContent = 'Submit Attendance';
        submitSpinner.classList.add('hidden');
        submitBtn.classList.remove('opacity-75', 'cursor-not-allowed');
    }
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastContent = document.getElementById('toast-content');
    
    let icon = '';
    let colorClass = '';
    
    if (type === 'success') {
        icon = `<svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;
        colorClass = 'border-green-500';
    } else {
        icon = `<svg class="h-6 w-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;
        colorClass = 'border-red-500';
    }
    
    toastContent.className = `bg-white border-l-4 rounded shadow-lg p-4 max-w-sm flex items-start ${colorClass}`;
    toastContent.innerHTML = `
        <div class="flex-shrink-0">
            ${icon}
        </div>
        <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium text-gray-900">${message}</p>
        </div>
    `;
    
    toast.classList.remove('translate-y-20', 'opacity-0');
    
    setTimeout(() => {
        toast.classList.add('translate-y-20', 'opacity-0');
    }, 3000);
}
