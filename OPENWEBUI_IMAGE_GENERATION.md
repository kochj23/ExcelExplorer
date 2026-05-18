# OpenWebUI - Image Generation Enabled

**Configured:** January 21, 2026
**Status:** ✅ Running with ComfyUI Integration

---

## ✅ What I Did

**Configured OpenWebUI with:**
1. ✅ **Authentication disabled** (no login required)
2. ✅ **Image generation enabled** (can create images)
3. ✅ **ComfyUI backend** (uses your existing ComfyUI at localhost:8188)
4. ✅ **Automatic1111 fallback** (if you have it running)
5. ✅ **Auto-restart** (survives Docker Desktop restarts)

**Docker Command Used:**
```bash
docker run -d \
  --name open-webui \
  -p 3000:8080 \
  -e WEBUI_AUTH=false \
  -e ENABLE_IMAGE_GENERATION=True \
  -e IMAGE_GENERATION_ENGINE=comfyui \
  -e COMFYUI_BASE_URL=http://host.docker.internal:8188 \
  -e AUTOMATIC1111_BASE_URL=http://host.docker.internal:7860 \
  -e IMAGE_STEPS=20 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main
```

**Environment Variables Set:**
- `WEBUI_AUTH=false` - No login needed
- `ENABLE_IMAGE_GENERATION=True` - Image gen enabled
- `IMAGE_GENERATION_ENGINE=comfyui` - Uses ComfyUI
- `COMFYUI_BASE_URL=http://host.docker.internal:8188` - Your ComfyUI
- `IMAGE_STEPS=20` - Quality/speed balance

---

## 🎯 How to Use

### **Access OpenWebUI:**
1. Open browser: http://localhost:3000
2. No login required (fresh installation)
3. Start chatting immediately

### **Generate Images in OpenWebUI:**

**Option 1: Direct Image Generation**
```
In chat, type:
"/image a professional data visualization chart showing sales trends"

OpenWebUI will:
1. Connect to your ComfyUI (localhost:8188)
2. Generate the image
3. Display it in the chat
4. Let you download it
```

**Option 2: In Conversation**
```
You: "Create an image of a bar chart showing revenue by region"
AI: [Generates and displays image]
```

**Option 3: Image Button**
```
Look for image generation button in OpenWebUI interface
Click it to open image generation dialog
Enter prompt
Generate
```

---

## 🔧 Technical Details

### **How It Works:**

**OpenWebUI → ComfyUI Connection:**
```
OpenWebUI (Docker container port 3000)
    ↓
host.docker.internal:8188
    ↓
Your Mac's ComfyUI (localhost:8188)
    ↓
Generates image using SD-XL
    ↓
Returns to OpenWebUI
    ↓
Displays in chat
```

**Key Setting:** `host.docker.internal`
- Docker's special hostname
- Lets container access Mac's localhost
- Required for ComfyUI connection

### **Image Generation Settings:**

**Engine:** ComfyUI (primary)
- Uses your existing ComfyUI installation
- Model: sd_xl_base_1.0.safetensors
- Steps: 20 (good quality/speed balance)
- Resolution: Defaults to 1024x1024

**Fallback:** Automatic1111
- If ComfyUI fails or is busy
- Falls back to A1111 if available

---

## 🎨 What You Can Generate

**In OpenWebUI, you can now:**

### **Data Visualizations:**
```
"Create a bar chart showing:
- Critical vulnerabilities: 1,234
- High severity: 2,567
- Medium: 890
- Low: 543"
```

### **Infographics:**
```
"Create a professional infographic showing
key metrics from my security report"
```

### **Diagrams:**
```
"Create a flow diagram showing the
vulnerability remediation process"
```

### **Icons and Graphics:**
```
"Create a security dashboard icon
in a modern blue and cyan style"
```

**Note:** Like all Stable Diffusion models, **text in images will be gibberish**. For data charts with readable text, use Excel Explorer's "Summarize & Visualize" feature (uses Swift Charts).

---

## 🔄 Integration with Excel Explorer

**OpenWebUI and Excel Explorer work together:**

### **For Text Analysis:**
- Excel Explorer can use OpenWebUI as AI backend
- Click "AI Config" → Should show "OpenWebUI - Available"
- AI queries go through OpenWebUI to Ollama

### **For Image Generation:**
- Both use the same ComfyUI backend
- Excel Explorer: Uses Swift Charts for readable data viz
- OpenWebUI: Uses ComfyUI for artistic/creative images

### **Best of Both Worlds:**
- **Excel Explorer:** Data charts with readable text
- **OpenWebUI:** Creative visualizations and graphics

---

## 🐛 Troubleshooting

### **Image Generation Not Working in OpenWebUI:**

**Check ComfyUI Status:**
```bash
curl http://localhost:8188/system_stats
# Should return JSON with system info
```

**Check OpenWebUI Logs:**
```bash
docker logs open-webui --tail 50
# Look for ComfyUI connection errors
```

**Verify Container Settings:**
```bash
docker exec open-webui env | grep IMAGE
# Should show ENABLE_IMAGE_GENERATION=True
```

**Test ComfyUI Connection from Container:**
```bash
docker exec open-webui curl -s http://host.docker.internal:8188/system_stats
# Should return ComfyUI stats
```

### **Common Issues:**

| Issue | Solution |
|-------|----------|
| "Image generation disabled" | Environment variable didn't apply - restart container |
| "ComfyUI not accessible" | Check `host.docker.internal` can reach localhost:8188 |
| "Generation failed" | Check ComfyUI console for errors |
| Takes too long | Normal - images take 30-60 seconds |

---

## 🔄 Docker Desktop Management

### **In Docker Desktop, you'll see:**

**Container: open-webui**
- Status: Running (green)
- Port: 3000:8080
- Restart: Unless stopped
- Volume: open-webui (persistent storage)

**Environment Variables:**
```
WEBUI_AUTH=false
ENABLE_IMAGE_GENERATION=True
IMAGE_GENERATION_ENGINE=comfyui
COMFYUI_BASE_URL=http://host.docker.internal:8188
IMAGE_STEPS=20
```

**To Restart:**
- Click the restart button in Docker Desktop
- Or: `docker restart open-webui`

**To Stop:**
- Click stop in Docker Desktop
- Or: `docker stop open-webui`

**To View Logs:**
- Click container → Logs tab
- Or: `docker logs open-webui -f`

---

## 📚 Resources

### **OpenWebUI Documentation:**
- Image Generation: https://docs.openwebui.com/features/image-generation
- ComfyUI Integration: https://docs.openwebui.com/integrations/comfyui
- Environment Variables: https://docs.openwebui.com/getting-started/env-configuration

### **Your Setup:**
- **OpenWebUI:** http://localhost:3000
- **ComfyUI:** http://localhost:8188
- **Excel Explorer:** /Applications/ExcelExplorer.app

---

## 🎯 Quick Test

**Test image generation in OpenWebUI:**

1. **Open browser:** http://localhost:3000

2. **In chat, type:**
   ```
   /image a beautiful sunset over mountains
   ```

3. **Wait 30-60 seconds**

4. **Image should appear in chat!**

**Or:**

1. **Type in chat:**
   ```
   Can you create an image of a professional data chart?
   ```

2. **AI should generate and display image**

---

## ✅ Summary

**OpenWebUI Now Has:**
- ✅ Authentication disabled (no login)
- ✅ Image generation enabled
- ✅ ComfyUI integration configured
- ✅ Automatic1111 fallback available
- ✅ Persistent storage (survives restarts)
- ✅ Auto-restart enabled

**Access:**
- Web UI: http://localhost:3000
- No login required
- Image generation available
- Uses your existing ComfyUI

**With Excel Explorer:**
- OpenWebUI available as AI backend
- Both use same ComfyUI for images
- Complementary features

---

## 💡 Best Practices

**Use OpenWebUI for:**
- Creative image generation
- Artistic visualizations
- Concept mockups
- UI/UX design images
- General AI chat

**Use Excel Explorer for:**
- Data analysis
- Chart generation with readable text
- Spreadsheet AI queries
- Professional data visualizations
- CSV/XLSX file analysis

**Together they make a powerful AI toolkit!**

---

**OpenWebUI is ready to use with image generation at http://localhost:3000!** 🎉
