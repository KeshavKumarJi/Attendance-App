async function login(username, password) {
    const formData = new URLSearchParams();
    formData.append('username', username);
    formData.append('password', password);

    try {
        const data = await apiFetch('/auth/login', {
            method: 'POST',
            body: formData
        });
        localStorage.setItem('token', data.access_token);
        return true;
    } catch (error) {
        console.error(error);
        return false;
    }
}

function logout() {
    localStorage.removeItem('token');
    window.location.href = 'login.html';
}

function requireAuth() {
    const token = localStorage.getItem('token');
    if (!token) {
        window.location.href = 'login.html';
    }
}

async function getCurrentTeacher() {
    return await apiFetch('/me');
}
