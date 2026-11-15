# Roblox Clone (Godot 4.3+)

1. Открой папку в Godot 4.3+ (Import -> project.godot), запусти (F5).
2. Впиши URL и anon key в `supabase_config.cfg` (Supabase -> Project Settings -> API).
   Для регистрации по email проверь Authentication -> Providers -> Email.
   Если включено подтверждение почты - после регистрации подтверди email, потом входи.
3. Без Supabase можно зайти кнопкой "Играть как гость".

Управление: WASD/стрелки - ходьба, Пробел - прыжок, ПКМ - вращать камеру, колесо - зум,
Esc - меню плейса, ` (Ё) или F1 - консоль.

Консоль: help, time set <0-24>, fps_show, reset, quit.

Новый плейс: сцена с Node3D + скрипт `extends PlaceBase` (переопредели _build_world()),
затем добавь запись в Game.PLACES (scripts/game.gd).
