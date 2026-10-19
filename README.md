# Veldara: Bond of the Wild — Caldra Arc (Godot 4.3, 2.5D, Online Co-op)

Prototype ที่ตรงกับเอกสารโปรเจกต์ v1.3 (ขอบเขต 1.0 = Caldra) ย้ายจาก Unity -> Godot
โลก 3D + มุมกล้อง 2.5D ใช้ procedural low-poly models สำหรับ Tamer/มอนสเตอร์ และฉากป่า-เมืองที่สร้างจาก mesh ภายใน Godot โดยไม่พึ่ง asset ภายนอก

## วิธีรัน
1. เปิดด้วย **Godot 4.3+** (Standard ไม่ต้องใช้ .NET) -> Import `project.godot` -> F5
2. คนที่ 1: กด **Host** | คนอื่น: ใส่ IP แล้วกด **Join** (UDP พอร์ต **7777**, สูงสุด 4 คน)
3. Dedicated server: `godot --headless --path . -- --server`  (เปิดพอร์ต UDP 7777)
   - ทดสอบฟักไข่เร็ว: `-- --server --egg-scale=0.005`
4. ทดสอบอัตโนมัติ: เปิด server แล้วรัน `godot --headless --path . -- --join=127.0.0.1 --bot`
   และ `godot --headless --path . res://tests/ui_test.tscn`

## ระบบต่อสู้แบบคู่หู (DMO-inspired)
- เทมเมอร์ทำหน้าที่เดินและออกคำสั่งเท่านั้น ไม่มีดาเมจโจมตีพื้นฐาน
- กด J เพื่อสั่งคู่หูล็อกเป้าหมายใกล้ที่สุดและต่อสู้อัตโนมัติ กด J อีกครั้งเพื่อหยุด
- กด K เพื่อให้คู่หูใช้สกิลธาตุกับเป้าหมายปัจจุบัน
- คู่หูเข้าไปประชิดเป้าหมายด้วยภาพโมเดลของตัวเอง; มอนสเตอร์ที่โจมตีผู้เล่นจะทำให้ HP คู่หูลดลง
- EXP จากการกำจัดมอนสเตอร์จะให้ทีมคู่หูตามระบบ Party เดิม

## ปุ่ม
WASD เดิน | J สั่งคู่หูต่อสู้อัตโนมัติ/หยุด (Tamer ไม่โจมตี) | K สกิลคู่หู | 1-4 เลือกตัว | Q ร่างถัดไป | E กลับ Sprout
R Bond Resonance | B/N เลือกกิ่ง Apex | M ปลุก Resonance
Debug (ปิดที่ `Net.debug_cheats`): F1 EXP, F2 Bond+Gauge เต็ม, F3 ไอเทม, F4 ฆ่าตัวที่ใช้ (ทดสอบไข่)

## โครงสร้าง
| ไฟล์ | หน้าที่ |
| --- | --- |
| autoload/data.gd | ธาตุ, ร่างทั้งหมด (`released` flag), ค่าตั้ง FormSwitchConfig, ตารางปฏิกิริยา, คำถามพิธีไข่ |
| autoload/net.gd | ENet host/join, เซฟมีเวอร์ชัน (`SAVE_VERSION` + `_migrate`), ปุ่มกด |
| scripts/monster_state.gd | MonsterState: EXP/เลเวล, MaxLevelByStage, กิ่ง Apex, Resonance, ไข่ Soft Death |
| scripts/party.gd | ทีม 4 ตัว, EE, Bond Gauge, Cooldown, Stamina, ฟักไข่ตามเวลาจริง (ออฟไลน์ได้) |
| scripts/player.gd | Tamer + RPC ทั้งหมด (server ตัดสิน, client ส่งคำสั่ง) |
| scripts/enemy.gd | มอนสเตอร์ป่า, ออร่าธาตุ, ปฏิกิริยา (Steam / Wildfire / Swirl) |
| scripts/world.gd | เมือง Caldra, บ้าน, น้ำพุคริสตัล, ถนน, ป่า, ต้นไม้, ดอกไม้, พื้นที่ปลอดภัย, spawner |
| scripts/visuals.gd | โมเดล low-poly ที่สร้างจาก mesh สำหรับ Tamer และมอนสเตอร์แต่ละธาตุ |
| scripts/hud.gd, starter_quiz.gd | HUD และพิธีไข่ (เห็น % เปลี่ยนใจได้ก่อนยืนยัน) |

## สถาปัตยกรรมออนไลน์
- Server (host หรือ dedicated) ถือ Party/ดาเมจ/ไข่/ศัตรู — client ส่งแค่ "คำสั่ง" (`req_action`) และตำแหน่งตัวเอง
- เซฟอยู่ฝั่ง server ที่ `user://saves/<profile_id>.json`
- **ข้อจำกัดที่รู้อยู่:** การเดินเป็น client-authoritative (โกงตำแหน่งได้), `profile_id` ยังไม่มีระบบล็อกอิน,
  ENet ใช้ในเบราว์เซอร์ไม่ได้ (ถ้าจะทำ Web ต้องเปลี่ยนเป็น WebSocket/WebRTC)

## ข้อสมมติฐานที่ผมตั้งเอง (เอกสารไม่ได้ระบุ ปรับใน data.gd)
- Resonance ต้อง Bond Level >= 8 | ต้นทุน EE 20/35/60 | EE ลด 2/4/6 ต่อวินาที | Stamina ลด 3/6/10
- เลเวลปลดล็อก Bloom 10 / Apex 25 / Resonance 40 | แคป Sprout 15 / Bloom 30 / Apex 50
- สไตล์ต่อสู้ (กิ่ง A/B) นับเป็นแต้มสะสม ต้อง >= 50
- เปลี่ยนชื่อปฏิกิริยาไฟ+พฤกษา จาก "Bloom" เป็น **Wildfire** (เอกสารบันทึกว่าชื่อซ้ำ)
- แจก Embit ทุกคนทันทีหลังพิธีไข่ (ข้อเสนอ "รอยืนยัน" ในเอกสาร)
- มีคำถามพิธีไข่ครบแค่ 2 ข้อ (เอกสารยังออกแบบไม่ครบ 7 ข้อ) เพิ่มต่อใน `Data.QUIZ` ได้เลย

## ยังไม่ทำ (ลำดับที่แนะนำ)
1. เควสต์ Kaelen/Tessa/Pip + Trust Lv.1-5 (มีช่อง `story_flags` และ `hatch_locked` ของไข่ Pip รอไว้แล้ว)
2. Pyrrhael + บอส Trial of the Cold Anvil | จับมอนสเตอร์ป่า | Box/Care | กาชา
3. เปลี่ยน procedural low-poly art เป็นโมเดล Blender/rig/แอนิเมชันจริงตามงบและเป้าหมายภาพ, ฟอนต์ไทยแบบ bundle (ถ้า export Web/มือถือ ต้องใส่ฟอนต์ไทยใน Theme เอง เช่น Noto Sans Thai)
4. ย้ายข้อมูลจาก Dictionary เป็น Resource (.tres) เมื่อเนื้อหาเยอะขึ้น
