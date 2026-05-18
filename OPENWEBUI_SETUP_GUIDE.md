# OpenWebUI - Complete Setup Guide with Image Generation

**Date:** January 21, 2026
**Status:** ✅ Ready for Configuration

---

## ✅ OpenWebUI is Running

**Container Status:** Running with authentication enabled
**URL:** http://localhost:3000
**Health:** Healthy ✅
**ComfyUI:** Connected to localhost:8188

---

## 📋 Step-by-Step Setup (Follow Exactly)

### **Step 1: Create Admin Account** (2 minutes)

1. **Open browser:** http://localhost:3000

2. **You'll see "Sign up" page**

3. **Fill in the form:**
   - Name: `Admin` (or your name)
   - Email: `admin@localhost` (or any email)
   - Password: `your_secure_password`

4. **Click "Create Account"**

5. **Important:** The FIRST account becomes the admin automatically

---

### **Step 2: Access Admin Panel** (30 seconds)

1. **After login**, look for your profile icon (top right)

2. **Click** the profile icon

3. **Select "Admin Panel"** from dropdown

4. **You're now in the admin interface**

---

### **Step 3: Enable Image Generation** (2 minutes)

1. **In Admin Panel**, look for sidebar menu

2. **Click "Settings"**

3. **Click "Images" tab** (or "Image Generation")

4. **You'll see image generation settings**

5. **Toggle "Enable Image Generation"** to ON

6. **Set these values:**
   - **Engine:** ComfyUI
   - **ComfyUI URL:** `http://host.docker.internal:8188`
   - **Steps:** 20
   - **Width:** 1024
   - **Height:** 1024

7. **Click "Save"** or "Update"

---

### **Step 4: Test Image Generation** (1 minute)

1. **Go back to main chat** (click "Chat" or "New Chat")

2. **In the chat input, type:**
   ```
   /image a professional business chart with blue colors
   ```

3. **Press Enter**

4. **Wait 30-60 seconds**

5. **Image should generate and appear!**

---

### **Step 5: Configure Ollama Connection** (1 minute)

1. **Back in Admin Panel → Settings**

2. **Click "Connections" or "External Connections"**

3. **Add Ollama:**
   - URL: `http://host.docker.internal:11434`
   - Or: `http://host.docker.internal:11434/api`

4. **Click "Verify" or "Test Connection"**

5. **Should show: Connected ✅**

6. **Save**

---

### **Step 6: (Optional) Disable Authentication** (1 minute)

**If you want no-login access:**

1. **Admin Panel → Settings**

2. **Click "Authentication" tab**

3. **Toggle "Enable Authentication"** to OFF

4. **Confirm the warning**

5. **Save**

6. **Note:** This only works if you want to allow anyone on your network to access

---

## 🎨 How to Generate Images in OpenWebUI

### **Method 1: Slash Command**
```
/image your prompt here
```

### **Method 2: Natural Language**
```
"Create an image of a data visualization chart"
```

### **Method 3: Image Button** (if visible in UI)
```
Click the image icon
Enter prompt
Generate
```

---

## 🔍 Troubleshooting

### **"Image generation is not enabled"**

**Solution:**
1. Make sure you're logged in as admin
2. Go to Admin Panel → Settings → Images
3. Toggle "Enable Image Generation" ON
4. Save changes
5. Refresh the page

### **"ComfyUI connection failed"**

**Solution:**
```bash
# 1. Verify ComfyUI is running
curl http://localhost:8188/system_stats

# 2. Test from container
docker exec open-webui curl -s http://host.docker.internal:8188/system_stats

# 3. Check OpenWebUI logs
docker logs open-webui --tail 50
```

### **"No image generated"**

**Check:**
1. ComfyUI is running and not busy
2. ComfyUI has the correct model (sd_xl_base_1.0.safetensors)
3. OpenWebUI has correct URL configured
4. Wait full 60 seconds (generation is slow)

---

## 🎯 Configuration Reference

### **OpenWebUI Admin Settings:**

**Images Tab:**
```
✅ Enable Image Generation: ON
Engine: ComfyUI
ComfyUI Base URL: http://host.docker.internal:8188
Steps: 20
Width: 1024
Height: 1024
Guidance Scale: 7.0
Sampler: euler
```

**Connections Tab:**
```
Ollama API URL: http://host.docker.internal:11434
```

**Authentication Tab:** (optional)
```
❌ Enable Authentication: OFF (if you want no-login)
```

---

## 📝 Current Docker Configuration

```bash
Container: open-webui
Port: 3000:8080
Env Variables:
  - ENABLE_IMAGE_GENERATION=True
  - IMAGE_GENERATION_ENGINE=comfyui
  - COMFYUI_BASE_URL=http://host.docker.internal:8188
  - IMAGE_STEPS=20
Host Mapping: host.docker.internal → your Mac
Volume: open-webui (persistent)
Restart: unless-stopped
```

---

## ✅ Success Criteria

**You'll know it's working when:**

1. **Login works** - Can access OpenWebUI without errors

2. **Admin Panel accessible** - Can see Settings → Images

3. **Image generation enabled** - Toggle is ON in settings

4. **Test works** - Type `/image test` and image generates

5. **ComfyUI connection** - Can see ComfyUI generating in its console

---

## 🚀 Go Do It Now!

**Follow the steps above:**

1. ✅ OpenWebUI is running (I already started it)
2. → **Open http://localhost:3000**
3. → **Create admin account**
4. → **Go to Admin Panel**
5. → **Settings → Images**
6. → **Enable image generation**
7. → **Save**
8. → **Test with `/image test`**

**This should take about 5 minutes total.**

Let me know when you're at Step 3 (Admin Panel) if you need help finding the image settings!

---

## 📊 Expected Result

**After configuration, you can:**
```
In OpenWebUI chat:
You: "/image a professional data chart"
AI: [Generates image using ComfyUI]
    [Image appears in chat]
    [Download button available]

In Excel Explorer:
You: Click "Summarize & Visualize"
AI: [Creates chart with Swift Charts]
    [Perfect readable text]
    [Professional styling]
```

**Both tools working together with your ComfyUI backend!** 🎉

---

**Go to http://localhost:3000 now and follow Steps 1-4 above!**
