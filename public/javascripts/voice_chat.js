console.log("voice_chat.js loaded");

const button = document.getElementById("record");
const status = document.getElementById("status");

button.onclick = async () => {
  console.log("mic clicked");
  status.textContent = "Recording...";
  
  console.log("recording started");
  
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const recorder = new MediaRecorder(stream);
  let chunks = [];

  recorder.ondataavailable = e => chunks.push(e.data);
  
  recorder.onstop = async () => {
    console.log("recording stopped");
    status.textContent = "Processing...";
    
    const blob = new Blob(chunks, { type: "audio/webm" });
    const formData = new FormData();
    formData.append("audio", blob, "recording.webm");

    // 1. Transcribe audio
    const res = await fetch("/transcribe", {
      method: "POST",
      body: formData
    });
    
    const data = await res.json();
    console.log("transcription received:", data);
    const userText = data.text || "No transcript";
    status.textContent = "You: " + userText;

    // 2. Send to chat
    const chatRes = await fetch("/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: userText })
    });

    const chatData = await chatRes.json();
    console.log("chat response received:", chatData);
    const aiText = chatData.choices?.[0]?.message?.content || "No response";
    status.textContent += "\nAI: " + aiText;

    // 3. Get speech
    const speechRes = await fetch("/speak", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: aiText })
    });

    console.log("audio received");
    const audioBlob = await speechRes.blob();
    const audioUrl = URL.createObjectURL(audioBlob);
    new Audio(audioUrl).play();
    
    status.textContent += "\nPlaying...";
  };

  recorder.start();
  setTimeout(() => recorder.stop(), 5000);
};
