// script.js

function showForm(formId) {
    document.querySelectorAll(".form-box")
        .forEach(form => form.classList.remove("active"));
    document.getElementById(formId).classList.add("active");
}

// For queries.php
function showQueryForm() {
    const sel = document.getElementById('queryType').value;
    document.querySelectorAll('.queryForm')
        .forEach(div => div.style.display = 'none');
    if (sel) document.getElementById('form_' + sel).style.display = 'block';
}
