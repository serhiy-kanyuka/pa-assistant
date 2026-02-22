var API_ENDPOINT = "https://api.pa.kanyuka.info";

var idToken = null;
var userProfile = null;
var selectedFiles = [];
var toastTimer = null;

var mediaRecorder = null;
var audioChunks = [];
var audioBlob = null;
var recordingStart = 0;
var timerInterval = null;

function showToast(message, isError) {
    var toast = document.getElementById("toast");
    toast.textContent = message;
    toast.className = "toast " + (isError ? "error" : "success");
    window.scrollTo({ top: 0, behavior: "smooth" });

    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
        toast.classList.add("hidden");
    }, isError ? 6000 : 4000);
}

function handleCredentialResponse(response) {
    idToken = response.credential;
    var parts = idToken.split(".");
    var b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    var payload = JSON.parse(atob(b64));

    userProfile = {
        email: payload.email,
        name: payload.name,
        picture: payload.picture,
    };

    document.getElementById("login-section").classList.add("hidden");
    document.getElementById("main-section").classList.remove("hidden");
    document.getElementById("user-info").classList.remove("hidden");
    document.getElementById("user-avatar").src = userProfile.picture;
    document.getElementById("user-name").textContent = userProfile.name;

    loadProjects();
}

function signOut() {
    idToken = null;
    userProfile = null;
    selectedFiles = [];
    stopRecordingCleanup();
    document.getElementById("login-section").classList.remove("hidden");
    document.getElementById("main-section").classList.add("hidden");
    document.getElementById("user-info").classList.add("hidden");
    document.getElementById("toast").classList.add("hidden");
}

function loadProjects() {
    fetch(API_ENDPOINT + "/api/projects", {
        headers: { Authorization: "Bearer " + idToken },
    })
        .then(function (resp) { return resp.json(); })
        .then(function (data) {
            var select = document.getElementById("project-select");
            while (select.options.length > 2) {
                select.remove(2);
            }
            var projects = data.projects || [];
            for (var i = 0; i < projects.length; i++) {
                var opt = document.createElement("option");
                opt.value = projects[i];
                opt.textContent = projects[i];
                select.insertBefore(opt, select.options[1]);
            }
        })
        .catch(function (err) {
            console.error("Failed to load projects:", err);
        });
}

function onProjectChange() {
    var select = document.getElementById("project-select");
    var newInput = document.getElementById("new-project-name");
    if (select.value === "__new__") {
        newInput.classList.remove("hidden");
        newInput.focus();
    } else {
        newInput.classList.add("hidden");
        newInput.value = "";
    }
}

function onActionChange() {
    var action = document.getElementById("action-select").value;
    var filesSection = document.getElementById("files-section");
    var audioSection = document.getElementById("audio-section");
    var notesGroup = document.getElementById("notes-input").parentElement;
    var btnText = document.getElementById("submit-text");
    var submitBtn = document.getElementById("submit-btn");

    filesSection.classList.add("hidden");
    audioSection.classList.add("hidden");
    notesGroup.classList.remove("hidden");
    submitBtn.classList.remove("hidden");

    if (action === "files") {
        filesSection.classList.remove("hidden");
        btnText.textContent = "Upload Files";
    } else if (action === "audio") {
        audioSection.classList.remove("hidden");
        notesGroup.classList.add("hidden");
        btnText.textContent = "Send Audio";
        submitBtn.classList.add("hidden");
        stopRecordingCleanup();
    } else {
        btnText.textContent = "Add Notes";
        selectedFiles = [];
        renderFileList();
        var fileInput = document.getElementById("file-upload");
        if (fileInput) fileInput.value = "";
    }
}

// --- Audio Recording ---

function toggleRecording() {
    if (mediaRecorder && mediaRecorder.state === "recording") {
        stopRecording();
    } else {
        startRecording();
    }
}

function startRecording() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        showToast("Audio recording is not supported on this browser.", true);
        return;
    }

    navigator.mediaDevices.getUserMedia({ audio: true })
        .then(function (stream) {
            audioChunks = [];
            audioBlob = null;

            var options = {};
            if (MediaRecorder.isTypeSupported("audio/webm;codecs=opus")) {
                options.mimeType = "audio/webm;codecs=opus";
            } else if (MediaRecorder.isTypeSupported("audio/mp4")) {
                options.mimeType = "audio/mp4";
            }

            mediaRecorder = new MediaRecorder(stream, options);

            mediaRecorder.ondataavailable = function (e) {
                if (e.data.size > 0) audioChunks.push(e.data);
            };

            mediaRecorder.onstop = function () {
                stream.getTracks().forEach(function (t) { t.stop(); });
                audioBlob = new Blob(audioChunks, { type: mediaRecorder.mimeType });
                showAudioPreview();
            };

            mediaRecorder.start(1000);
            recordingStart = Date.now();
            updateTimer();
            timerInterval = setInterval(updateTimer, 500);

            document.getElementById("record-btn").classList.add("recording");
            document.getElementById("record-label").textContent = "Tap to Stop";
            document.getElementById("record-timer").classList.remove("hidden");
            document.getElementById("audio-preview").classList.add("hidden");
            document.getElementById("submit-btn").classList.add("hidden");
        })
        .catch(function (err) {
            showToast("Microphone access denied: " + err.message, true);
        });
}

function stopRecording() {
    if (mediaRecorder && mediaRecorder.state === "recording") {
        mediaRecorder.stop();
    }
    clearInterval(timerInterval);
    document.getElementById("record-btn").classList.remove("recording");
    document.getElementById("record-label").textContent = "Tap to Record";
}

function stopRecordingCleanup() {
    if (mediaRecorder && mediaRecorder.state === "recording") {
        mediaRecorder.stream.getTracks().forEach(function (t) { t.stop(); });
        mediaRecorder.stop();
    }
    clearInterval(timerInterval);
    mediaRecorder = null;
    audioChunks = [];
    audioBlob = null;
    var btn = document.getElementById("record-btn");
    if (btn) {
        btn.classList.remove("recording");
        document.getElementById("record-label").textContent = "Tap to Record";
        document.getElementById("record-timer").classList.add("hidden");
        document.getElementById("record-timer").textContent = "00:00";
        document.getElementById("audio-preview").classList.add("hidden");
    }
}

function updateTimer() {
    var elapsed = Math.floor((Date.now() - recordingStart) / 1000);
    var mins = String(Math.floor(elapsed / 60)).padStart(2, "0");
    var secs = String(elapsed % 60).padStart(2, "0");
    document.getElementById("record-timer").textContent = mins + ":" + secs;
}

function showAudioPreview() {
    var url = URL.createObjectURL(audioBlob);
    var player = document.getElementById("audio-player");
    player.src = url;
    document.getElementById("audio-preview").classList.remove("hidden");
    document.getElementById("submit-btn").classList.remove("hidden");
    document.getElementById("submit-text").textContent = "Send Audio";
}

function discardRecording() {
    audioBlob = null;
    audioChunks = [];
    document.getElementById("audio-preview").classList.add("hidden");
    document.getElementById("submit-btn").classList.add("hidden");
    document.getElementById("record-timer").classList.add("hidden");
    document.getElementById("record-timer").textContent = "00:00";
}

// --- File list ---

function updateFileList() {
    var input = document.getElementById("file-upload");
    selectedFiles = Array.from(input.files);
    renderFileList();
}

function renderFileList() {
    var list = document.getElementById("file-list");
    list.innerHTML = "";
    for (var i = 0; i < selectedFiles.length; i++) {
        var file = selectedFiles[i];
        var li = document.createElement("li");
        var size = file.size < 1024
            ? file.size + " B"
            : file.size < 1048576
                ? (file.size / 1024).toFixed(1) + " KB"
                : (file.size / 1048576).toFixed(1) + " MB";
        li.innerHTML =
            "<span>" + file.name + ' <span class="file-size">(' + size + ")</span></span>" +
            '<button class="remove-file" type="button" onclick="removeFile(' + i + ')">&times;</button>';
        list.appendChild(li);
    }
}

function removeFile(idx) {
    selectedFiles.splice(idx, 1);
    renderFileList();
}

// --- Submit ---

function submitRequest(event) {
    event.preventDefault();

    var select = document.getElementById("project-select");
    var newProjectName = document.getElementById("new-project-name").value.trim();
    var action = document.getElementById("action-select").value;
    var notes = document.getElementById("notes-input").value.trim();
    var instruction = document.getElementById("instruction-input").value.trim();

    var project = select.value === "__new__" ? "" : select.value;

    if (select.value === "__new__" && !newProjectName) {
        showToast("Please enter a name for the new project.", true);
        document.getElementById("new-project-name").focus();
        return;
    }
    if (!select.value) {
        showToast("Please select a project.", true);
        return;
    }
    if (action === "notes" && !notes) {
        showToast("Please enter notes.", true);
        document.getElementById("notes-input").focus();
        return;
    }
    if (action === "files" && selectedFiles.length === 0) {
        showToast("Please attach at least one file.", true);
        return;
    }
    if (action === "audio" && !audioBlob) {
        showToast("Please record an audio note first.", true);
        return;
    }

    var btn = document.getElementById("submit-btn");
    var btnText = document.getElementById("submit-text");
    var spinner = document.getElementById("submit-spinner");

    btn.disabled = true;
    btnText.textContent = "Sending...";
    spinner.classList.remove("hidden");

    var formData = new FormData();
    formData.append("project", project);
    formData.append("new_project", newProjectName);
    formData.append("action", action);
    formData.append("notes", notes);
    formData.append("instruction", instruction);

    if (action === "files") {
        for (var i = 0; i < selectedFiles.length; i++) {
            formData.append("files", selectedFiles[i], selectedFiles[i].name);
        }
    }

    if (action === "audio" && audioBlob) {
        var ext = audioBlob.type.indexOf("mp4") !== -1 ? ".m4a" : ".webm";
        var now = new Date();
        var audioName = "audio_note_" +
            now.getFullYear() +
            String(now.getMonth() + 1).padStart(2, "0") +
            String(now.getDate()).padStart(2, "0") + "_" +
            String(now.getHours()).padStart(2, "0") +
            String(now.getMinutes()).padStart(2, "0") +
            String(now.getSeconds()).padStart(2, "0") + ext;
        formData.append("files", audioBlob, audioName);
    }

    fetch(API_ENDPOINT + "/api/request", {
        method: "POST",
        headers: { Authorization: "Bearer " + idToken },
        body: formData,
    })
        .then(function (resp) {
            return resp.json().then(function (data) {
                return { ok: resp.ok, data: data };
            });
        })
        .then(function (result) {
            if (result.ok) {
                var target = newProjectName || project;
                var msg = action === "notes" ? "Notes added to " + target
                    : action === "audio" ? "Audio note saved to " + target
                    : "Files uploaded to " + target;
                showToast(msg, false);

                document.getElementById("notes-input").value = "";
                document.getElementById("instruction-input").value = "";
                selectedFiles = [];
                renderFileList();
                var fileInput = document.getElementById("file-upload");
                if (fileInput) fileInput.value = "";

                if (action === "audio") {
                    discardRecording();
                }

                if (newProjectName) {
                    loadProjects();
                    document.getElementById("project-select").value = "";
                    document.getElementById("new-project-name").classList.add("hidden");
                    document.getElementById("new-project-name").value = "";
                }

                if (action !== "audio") {
                    document.getElementById("notes-input").focus();
                }
            } else {
                showToast("Failed: " + (result.data.error || "Unknown error"), true);
            }
        })
        .catch(function (err) {
            showToast("Network error: " + err.message, true);
        })
        .finally(function () {
            btn.disabled = false;
            var currentAction = document.getElementById("action-select").value;
            spinner.classList.add("hidden");
            if (currentAction === "files") {
                btnText.textContent = "Upload Files";
            } else if (currentAction === "audio") {
                btnText.textContent = "Send Audio";
                if (!audioBlob) btn.classList.add("hidden");
            } else {
                btnText.textContent = "Add Notes";
            }
        });
}

// Drag & drop
var dropZone = document.getElementById("drop-zone");
if (dropZone) {
    dropZone.addEventListener("dragover", function (e) {
        e.preventDefault();
        dropZone.classList.add("dragover");
    });
    dropZone.addEventListener("dragleave", function () {
        dropZone.classList.remove("dragover");
    });
    dropZone.addEventListener("drop", function (e) {
        e.preventDefault();
        dropZone.classList.remove("dragover");
        var newFiles = Array.from(e.dataTransfer.files);
        selectedFiles = selectedFiles.concat(newFiles);
        renderFileList();
    });
}
