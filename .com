<!DOCTYPE html>
<html lang="ur" dir="ltr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CyberVerse 3D - Professional Web Game</title>
  <style>
    :root {
      --primary: #00f2fe;
      --secondary: #4facfe;
      --bg-glass: rgba(15, 23, 42, 0.75);
      --border-glass: rgba(255, 255, 255, 0.1);
      --font-main: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
    }

    body, html {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #05050a;
      font-family: var(--font-main);
      color: #fff;
    }

    #webgl-canvas {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: 1;
    }

    /* UI Layer */
    .ui-layer {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: 10;
      pointer-events: none;
    }

    .interactive {
      pointer-events: auto;
    }

    /* Professional Glassmorphic Menu */
    .menu-screen {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at center, rgba(10, 15, 30, 0.6) 0%, rgba(5, 5, 10, 0.95) 100%);
      backdrop-filter: blur(8px);
      transition: opacity 0.4s ease, visibility 0.4s;
    }

    .menu-screen.hidden {
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }

    .menu-card {
      background: var(--bg-glass);
      border: 1px solid var(--border-glass);
      border-radius: 16px;
      padding: 40px 50px;
      text-align: center;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 242, 254, 0.1);
      max-width: 450px;
      width: 90%;
    }

    .game-title {
      font-size: 2.8rem;
      font-weight: 800;
      letter-spacing: 2px;
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
      text-transform: uppercase;
    }

    .game-subtitle {
      color: #94a3b8;
      font-size: 0.95rem;
      margin-bottom: 30px;
      letter-spacing: 1px;
    }

    .menu-actions {
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    .btn {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-glass);
      color: #fff;
      padding: 14px 20px;
      font-size: 1rem;
      font-weight: 600;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.25s ease;
      letter-spacing: 0.5px;
    }

    .btn:hover {
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      color: #000;
      box-shadow: 0 0 20px rgba(0, 242, 254, 0.4);
      transform: translateY(-2px);
    }

    .controls-hint {
      margin-top: 25px;
      font-size: 0.85rem;
      color: #64748b;
      line-height: 1.5;
    }

    /* In-Game HUD */
    .hud {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      padding: 20px 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      transition: opacity 0.3s ease;
    }

    .hud.hidden {
      display: none;
    }

    .hud-box {
      background: var(--bg-glass);
      border: 1px solid var(--border-glass);
      padding: 10px 20px;
      border-radius: 10px;
      font-size: 1.1rem;
      font-weight: 600;
      color: var(--primary);
    }

    .btn-pause {
      padding: 8px 16px;
      font-size: 0.9rem;
    }
  </style>
  <!-- Three.js Library -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
</head>
<body>

  <!-- 3D Viewport -->
  <canvas id="webgl-canvas"></canvas>

  <!-- UI Overlay -->
  <div class="ui-layer">
    
    <!-- HUD Screen -->
    <div id="hud" class="hud hidden">
      <div class="hud-box">SCORE: <span id="score-val">0</span></div>
      <button id="pause-btn" class="btn btn-pause interactive">PAUSE (ESC)</button>
    </div>

    <!-- Main Home / Landing Menu -->
    <div id="main-menu" class="menu-screen interactive">
      <div class="menu-card">
        <h1 class="game-title">CyberVerse</h1>
        <p class="game-subtitle">3D Real-Time Web Experience</p>
        
        <div class="menu-actions">
          <button id="start-btn" class="btn">START MISSION</button>
          <button id="instructions-btn" class="btn">CONTROLS</button>
        </div>

        <div class="controls-hint">
          Use <b>W, A, S, D</b> or <b>Arrow Keys</b> to navigate.<br>Collect glowing energy orbs to score.
        </div>
      </div>
    </div>

    <!-- Pause Menu -->
    <div id="pause-menu" class="menu-screen hidden interactive">
      <div class="menu-card">
        <h2 class="game-title" style="font-size: 2rem;">Paused</h2>
        <div class="menu-actions" style="margin-top: 20px;">
          <button id="resume-btn" class="btn">RESUME</button>
          <button id="restart-btn" class="btn">RESTART</button>
        </div>
      </div>
    </div>

  </div>

  <script>
    /* ========================================================
       GAME STATE & VARIABLES
       ======================================================== */
    const State = {
      MENU: 0,
      PLAYING: 1,
      PAUSED: 2
    };

    let currentState = State.MENU;
    let score = 0;

    // DOM Elements
    const mainMenu = document.getElementById('main-menu');
    const pauseMenu = document.getElementById('pause-menu');
    const hud = document.getElementById('hud');
    const scoreVal = document.getElementById('score-val');

    /* ========================================================
       THREE.JS SETUP (SCENE, CAMERA, RENDERER)
       ======================================================== */
    const canvas = document.getElementById('webgl-canvas');
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a0c16);
    scene.fog = new THREE.FogExp2(0x0a0c16, 0.02);

    const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
    const renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, powerPreference: "high-performance" });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    /* ========================================================
       ENVIRONMENT & LIGHTING
       ======================================================== */
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0x00f2fe, 1.2);
    sunLight.position.set(20, 40, 20);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 2048;
    sunLight.shadow.mapSize.height = 2048;
    sunLight.shadow.camera.near = 0.5;
    sunLight.shadow.camera.far = 100;
    sunLight.shadow.camera.left = -30;
    sunLight.shadow.camera.right = 30;
    sunLight.shadow.camera.top = 30;
    sunLight.shadow.camera.bottom = -30;
    scene.add(sunLight);

    // Grid Floor
    const floorGeo = new THREE.PlaneGeometry(120, 120);
    const floorMat = new THREE.MeshStandardMaterial({ 
      color: 0x111625, 
      roughness: 0.3, 
      metalness: 0.8 
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.receiveShadow = true;
    scene.add(floor);

    const gridHelper = new THREE.GridHelper(120, 60, 0x00f2fe, 0x1e293b);
    gridHelper.position.y = 0.02;
    scene.add(gridHelper);

    /* ========================================================
       PLAYER OBJECT (CYBER VEHICLE / CHARACTER)
       ======================================================== */
    const playerGroup = new THREE.Group();

    // Body
    const bodyGeo = new THREE.BoxGeometry(1.6, 0.6, 2.4);
    const bodyMat = new THREE.MeshStandardMaterial({ 
      color: 0x00f2fe, 
      metalness: 0.9, 
      roughness: 0.1,
      emissive: 0x003344,
      emissiveIntensity: 0.5
    });
    const playerBody = new THREE.Mesh(bodyGeo, bodyMat);
    playerBody.position.y = 0.5;
    playerBody.castShadow = true;
    playerGroup.add(playerBody);

    // Glowing Core
    const coreGeo = new THREE.SphereGeometry(0.35, 16, 16);
    const coreMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    const core = new THREE.Mesh(coreGeo, coreMat);
    core.position.set(0, 0.8, 0);
    playerGroup.add(core);

    scene.add(playerGroup);

    /* ========================================================
       OBSTACLES & COLLECTIBLES
       ======================================================== */
    const collectibles = [];
    const orbGeo = new THREE.IcosahedronGeometry(0.5, 2);
    const orbMat = new THREE.MeshStandardMaterial({ 
      color: 0xff007f, 
      emissive: 0xff007f, 
      emissiveIntensity: 0.8,
      roughness: 0.1 
    });

    function spawnCollectibles() {
      // Clear existing
      collectibles.forEach(c => scene.remove(c));
      collectibles.length = 0;

      for (let i = 0; i < 15; i++) {
        const orb = new THREE.Mesh(orbGeo, orbMat);
        orb.position.set(
          (Math.random() - 0.5) * 80,
          0.8,
          (Math.random() - 0.5) * 80
        );
        orb.castShadow = true;
        scene.add(orb);
        collectibles.push(orb);
      }
    }
    spawnCollectibles();

    // Environment Pillars
    const pillarGeo = new THREE.BoxGeometry(2, 8, 2);
    const pillarMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.5 });
    for (let i = 0; i < 20; i++) {
      const pillar = new THREE.Mesh(pillarGeo, pillarMat);
      pillar.position.set(
        (Math.random() - 0.5) * 100,
        4,
        (Math.random() - 0.5) * 100
      );
      pillar.castShadow = true;
      pillar.receiveShadow = true;
      scene.add(pillar);
    }

    /* ========================================================
       INPUTS & CONTROLS
       ======================================================== */
    const keys = { forward: false, backward: false, left: false, right: false };

    window.addEventListener('keydown', (e) => {
      if (e.code === 'KeyW' || e.code === 'ArrowUp') keys.forward = true;
      if (e.code === 'KeyS' || e.code === 'ArrowDown') keys.backward = true;
      if (e.code === 'KeyA' || e.code === 'ArrowLeft') keys.left = true;
      if (e.code === 'KeyD' || e.code === 'ArrowRight') keys.right = true;

      if (e.code === 'Escape') togglePause();
    });

    window.addEventListener('keyup', (e) => {
      if (e.code === 'KeyW' || e.code === 'ArrowUp') keys.forward = false;
      if (e.code === 'KeyS' || e.code === 'ArrowDown') keys.backward = false;
      if (e.code === 'KeyA' || e.code === 'ArrowLeft') keys.left = false;
      if (e.code === 'KeyD' || e.code === 'ArrowRight') keys.right = false;
    });

    /* ========================================================
       GAME ACTIONS & MENU HANDLING
       ======================================================== */
    function startGame() {
      currentState = State.PLAYING;
      mainMenu.classList.add('hidden');
      hud.classList.remove('hidden');
      score = 0;
      scoreVal.textContent = score;
      playerGroup.position.set(0, 0, 0);
      spawnCollectibles();
    }

    function togglePause() {
      if (currentState === State.PLAYING) {
        currentState = State.PAUSED;
        pauseMenu.classList.remove('hidden');
      } else if (currentState === State.PAUSED) {
        currentState = State.PLAYING;
        pauseMenu.classList.add('hidden');
      }
    }

    document.getElementById('start-btn').addEventListener('click', startGame);
    document.getElementById('pause-btn').addEventListener('click', togglePause);
    document.getElementById('resume-btn').addEventListener('click', togglePause);
    document.getElementById('restart-btn').addEventListener('click', () => {
      pauseMenu.classList.add('hidden');
      startGame();
    });

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    /* ========================================================
       ANIMATION & PHYSICS LOOP
       ======================================================== */
    let speed = 0;
    const maxSpeed = 0.4;
    const acceleration = 0.02;
    const friction = 0.95;
    let turnAngle = 0;

    const clock = new THREE.Clock();

    function animate() {
      requestAnimationFrame(animate);
      const delta = clock.getDelta();
      const time = clock.getElapsedTime();

      // Collectibles floating animation
      collectibles.forEach((orb, index) => {
        orb.rotation.y += 0.02;
        orb.position.y = 0.8 + Math.sin(time * 3 + index) * 0.2;
      });

      if (currentState === State.PLAYING) {
        // Player Mechanics
        if (keys.forward) speed = Math.min(speed + acceleration, maxSpeed);
        if (keys.backward) speed = Math.max(speed - acceleration, -maxSpeed * 0.5);
        if (keys.left) turnAngle += 0.04;
        if (keys.right) turnAngle -= 0.04;

        speed *= friction;
        playerGroup.rotation.y = turnAngle;

        playerGroup.position.x += Math.sin(turnAngle) * -speed;
        playerGroup.position.z += Math.cos(turnAngle) * -speed;

        // Collectibles Detection
        for (let i = collectibles.length - 1; i >= 0; i--) {
          const dist = playerGroup.position.distanceTo(collectibles[i].position);
          if (dist < 1.5) {
            scene.remove(collectibles[i]);
            collectibles.splice(i, 1);
            score += 100;
            scoreVal.textContent = score;

            if (collectibles.length === 0) spawnCollectibles();
          }
        }

        // Third Person Camera Follow
        const camDistance = 10;
        const camHeight = 5;
        const targetX = playerGroup.position.x + Math.sin(turnAngle) * camDistance;
        const targetZ = playerGroup.position.z + Math.cos(turnAngle) * camDistance;

        camera.position.x += (targetX - camera.position.x) * 0.1;
        camera.position.z += (targetZ - camera.position.z) * 0.1;
        camera.position.y += (playerGroup.position.y + camHeight - camera.position.y) * 0.1;
        camera.lookAt(playerGroup.position.x, playerGroup.position.y + 1, playerGroup.position.z);

      } else if (currentState === State.MENU) {
        // Menu Cinematic Camera Rotation
        const radius = 25;
        camera.position.x = Math.sin(time * 0.2) * radius;
        camera.position.z = Math.cos(time * 0.2) * radius;
        camera.position.y = 12;
        camera.lookAt(0, 0, 0);
      }

      renderer.render(scene, camera);
    }

    animate();
  </script>
</body>
</html>
