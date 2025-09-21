WIDTH       = 1280
HEIGHT      = 720
GAME_WIDTH  = 1260
GAME_HEIGHT = 700

ZOOM_WIDTH   = (WIDTH / GAME_WIDTH).floor
ZOOM_HEIGHT  = (HEIGHT / GAME_HEIGHT).floor
ZOOM         = [ZOOM_WIDTH, ZOOM_HEIGHT].min
OFFSET_X     = ((WIDTH - GAME_WIDTH * ZOOM) / 2).floor
OFFSET_Y     = ((HEIGHT - GAME_HEIGHT * ZOOM) / 2).floor
ZOOMED_WIDTH  = GAME_WIDTH * ZOOM
ZOOMED_HEIGHT = GAME_HEIGHT * ZOOM

GRID_WIDTH  = 10
GRID_HEIGHT = 10
TILE_SIZE   = 64

RESOURCE_TYPES = [:seed, :soil, :water, :sun, :brick]

WATER_FRAME_COUNT = 10
WATER_TICKS_PER_FRAME = 6

GRID_PIXEL_WIDTH  = GRID_WIDTH * TILE_SIZE
GRID_PIXEL_HEIGHT = GRID_HEIGHT * TILE_SIZE

GRID_OFFSET_X = ((GAME_WIDTH - GRID_PIXEL_WIDTH) / 2).floor
GRID_OFFSET_Y = ((GAME_HEIGHT - GRID_PIXEL_HEIGHT) / 2).floor

SHAPES = {
  o_shape: [
    [[0,0],[1,0],[0,1],[1,1]]
  ],
  j_shape: [
    [[0,0],[0,1],[0,2],[1,2]],
    [[0,1],[1,1],[2,1],[2,0]],
    [[0,0],[1,0],[1,1],[1,2]],
    [[0,0],[0,1],[1,0],[2,0]]
  ],
  l_shape: [
    [[1,0],[1,1],[1,2],[0,2]],
    [[0,0],[0,1],[1,1],[2,1]],
    [[0,0],[0,1],[0,2],[1,0]],
    [[0,0],[1,0],[2,0],[2,1]]
  ],
  t_shape: [
    [[0,1],[1,0],[1,1],[2,1]],
    [[1,0],[1,1],[1,2],[0,1]],
    [[0,0],[1,0],[2,0],[1,1]],
    [[0,0],[0,1],[0,2],[1,1]]
  ],
  i_shape: [
    [[0,0],[0,1],[0,2],[0,3]],
    [[0,0],[1,0],[2,0],[3,0]]
  ],
  s_shape: [
    [[1,0],[2,0],[0,1],[1,1]],
    [[0,0],[0,1],[1,1],[1,2]]
  ],
  z_shape: [
    [[0,0],[1,0],[1,1],[2,1]],
    [[1,0],[0,1],[1,1],[0,2]]
  ]
}

BLINK_COLORS = {
  o_shape: { r: 255, g: 255, b: 0  , a: 128 }, # Yellow
  j_shape: { r: 0,   g: 0,   b: 255, a: 128 }, # Blue
  l_shape: { r: 255, g: 165, b: 0  , a: 128 }, # Orange
  t_shape: { r: 128, g: 0,   b: 128, a: 128 }, # Purple
  i_shape: { r: 0,   g: 255, b: 255, a: 128 }, # Cyan
  s_shape: { r: 0,   g: 255, b: 0  , a: 128 }, # Green
  z_shape: { r: 255, g: 0,   b: 0  , a: 128 }, # Red
  trapped_resources: { r: 25, g: 50, b: 25 }   # Background Green
}

FLOWER_TYPES = {
  o_shape: :flower_daisy,
  j_shape: :flower_rose,
  l_shape: :flower_tulip,
  t_shape: :flower_sunflower,
  i_shape: :flower_orchid,
  s_shape: :flower_lily,
  z_shape: :flower_peony
}

FLOWER_SHAPES = SHAPES.transform_keys do |shape_name|
  :"#{shape_name}_flowers"
end.transform_values do |orientations|
  orientations.map do |coords|
    FLOWER_TYPES.map do |_, flower_type|
      { coords: coords, types: Array.new(coords.size, flower_type) }
    end
  end.flatten
end

ALL_SHAPES = SHAPES.transform_values do |orientations|
  orientations.map { |coords| { coords: coords, types: RESOURCE_TYPES.reject { |t| t == :brick } } }
end.merge(FLOWER_SHAPES) #.merge(FIXED_SHAPES)

def self.boot args
  args.state = {}
  bootstrap
end

def self.bootstrap
  $gg = {
    current_scene: :tick_setup,
    next_scene: :tick_setup,
    camera_trauma: 0.5,
    camera_x_offset: 0,
    camera_y_offset: 0,
    score: 0,
    total_score: 0,
    high_score: 0,
    clock: 0,
    lost_focus: true,
    bag: [],
    title_flowers: [],
    blinking_shapes: [],
    falling_blocks: [],
    moved_loose_blocks: [],
    loose_blocks: nil,
    left_moved_at: 0,
    left_pending: false,
    left_cooldown: 8,
    right_moved_at: 0,
    right_pending: false,
    right_cooldown: 8,
    tmp_blocks: [],
    tmp_types: [],
    tmp_bricks: [],
    tmp_sprites: [],
    cascade_multiplier: 1,
    wave: 1,
    wiggle_phase: 0,
    held_piece: nil,
    hold_used_this_drop: false,
    soft_drop_allowed: true,
    grid: Array.new(GRID_WIDTH * GRID_HEIGHT),
    hold_piece_rect: { x: 0, y: 480, w: 256, h: 240 },
    touch_left_rect: { x: 0, y: 180, w: 640, h: 540 },
    touch_right_rect: { x: 640, y: 180, w: 640, h: 540 },
    touch_down_rect: { x: 0, y: 0, w: 1280, h: 180 }
  }
end

def self.reset args
  bootstrap
end

def self.tick args
  $outputs.background_color = [0, 0, 0]

  game_has_lost_focus?

  $outputs[:garden].w = GAME_WIDTH
  $outputs[:garden].h = GAME_HEIGHT
  $outputs[:garden].background_color = [25, 50, 25]

  $gg.mouse_position = {
    x: ($inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: ($inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1,
    h: 1
  }

  screenshake

  send($gg.current_scene)

  $outputs.primitives << {
    x: WIDTH / 2 + $gg.camera_x_offset,
    y: HEIGHT / 2 + $gg.camera_y_offset,
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: :garden,
  }

  $gg.clock += 1 unless $gg.lost_focus

  $gg.current_scene = $gg.next_scene if $gg.current_scene != $gg.next_scene
end

def self.tick_game
  unless $gg.lost_focus
    if any_loose_blocks?
      $gg.loose_blocks = :true
    else
      if $gg.pending_shape_check
        check_for_flower_clusters
        $gg.pending_shape_check = false

        unless any_loose_blocks? || $gg.falling_blocks.any?
          check_trapped_resources
        end
      end
      $gg.loose_blocks = nil
    end

    unless $gg.loose_blocks
      if $gg.falling_blocks.empty?
        unless $gg.blinking_shapes.any?
          check_wave_completion
          $gg.hold_used_this_drop = false
          $gg.soft_drop_allowed = false
          spawn_falling_block
        end
      end
    end

    move_loose_blocks_down if $gg.loose_blocks

    handle_block_input
    handle_touch_input
  end

  render_grid

  update_flower_rotations if $gg.clock % 10 == 0 unless $gg.lost_focus

  if $gg.score < $gg.total_score
    increment =
      if $gg.total_score - $gg.score >= 150
        150
      elsif $gg.total_score - $gg.score >= 25
        25
      elsif $gg.total_score - $gg.score >= 10
        10
      else
        1
      end

    $gg.score += increment
    $gg.score = $gg.total_score if $gg.score > $gg.total_score
    sound_score

    if $gg.score > $gg.high_score
      $gg.high_score = $gg.score
      $gtk.write_file "data/high_score.txt", $gg.high_score.to_s
    end
  end
end

def self.sound_score
  $audio[rand] = {
    input: 'sounds/tinkerbell.ogg',  # Filename
    x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
    gain: 0.2,                       # Volume (0.0 to 1.0)
    pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
    paused: false,                   # Set to true to pause the sound at the current playback position
    looping: false                   # Set to true to loop the sound/music until you stop it
  }
end

def self.sound_shape
  $audio[:shape] ||= {
    input: 'sounds/greenhit.ogg',    # Filename
    x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
    gain: 0.5,                       # Volume (0.0 to 1.0)
    pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
    paused: false,                   # Set to true to pause the sound at the current playback position
    looping: false                   # Set to true to loop the sound/music until you stop it
  }
end

def self.sound_block
  $audio[:block] ||= {
    input: 'sounds/pop.ogg',         # Filename
    x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
    gain: 0.5,                       # Volume (0.0 to 1.0)
    pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
    paused: false,                   # Set to true to pause the sound at the current playback position
    looping: false                   # Set to true to loop the sound/music until you stop it
  }
end

def self.sound_hold
  $audio[:hold] ||= {
    input: 'sounds/swish1.ogg',      # Filename
    x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
    gain: 0.5,                       # Volume (0.0 to 1.0)
    pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
    paused: false,                   # Set to true to pause the sound at the current playback position
    looping: false                   # Set to true to loop the sound/music until you stop it
  }
end

def self.handle_block_input
  return if $gg.lost_focus

  if $inputs.keyboard.left
    if $gg.clock - $gg.left_moved_at >= $gg.left_cooldown
      move_block_left
      $gg.left_moved_at = $gg.clock
      $gg.left_pending = false
    else
      $gg.left_pending = true
    end
  elsif $gg.left_pending && $gg.clock - $gg.left_moved_at >= $gg.left_cooldown
    move_block_left
    $gg.left_moved_at = $gg.clock
    $gg.left_pending = false
  else
    $gg.left_pending = false
  end

  if $inputs.keyboard.right
    if $gg.clock - $gg.right_moved_at >= $gg.right_cooldown
      move_block_right
      $gg.right_moved_at = $gg.clock
      $gg.right_pending = false
    else
      $gg.right_pending = true
    end
  elsif $gg.right_pending && $gg.clock - $gg.right_moved_at >= $gg.right_cooldown
    move_block_right
    $gg.right_moved_at = $gg.clock
    $gg.right_pending = false
  else
    $gg.right_pending = false
  end

  $gg.soft_drop_allowed = true if !$inputs.keyboard.down && !$inputs.mouse.down

  move_block_down if $inputs.keyboard.down && $gg.soft_drop_allowed

  move_block_down if $gg.clock % 30 == 0

  if $inputs.keyboard.key_down.space
    hold_current_piece
  end
end

def self.handle_touch_input
  return if $gg.lost_focus
  return if !$inputs.mouse.click

  if check_touch_left
    if $gg.clock - $gg.left_moved_at >= $gg.left_cooldown
      move_block_left
      $gg.left_moved_at = $gg.clock
      $gg.left_pending = false
    else
      $gg.left_pending = true
    end
  elsif $gg.left_pending && $gg.clock - $gg.left_moved_at >= $gg.left_cooldown
    move_block_left
    $gg.left_moved_at = $gg.clock
    $gg.left_pending = false
  else
    $gg.left_pending = false
  end

  if check_touch_right
    if $gg.clock - $gg.right_moved_at >= $gg.right_cooldown
      move_block_right
      $gg.right_moved_at = $gg.clock
      $gg.right_pending = false
    else
      $gg.right_pending = true
    end
  elsif $gg.right_pending && $gg.clock - $gg.right_moved_at >= $gg.right_cooldown
    move_block_right
    $gg.right_moved_at = $gg.clock
    $gg.right_pending = false
  else
    $gg.right_pending = false
  end

  $gg.soft_drop_allowed = true if !$inputs.keyboard.down && !$inputs.mouse.down

  move_block_down if check_touch_down && $gg.soft_drop_allowed

  # move_block_down if $gg.clock % 30 == 0

  if $inputs.mouse.inside_rect? $gg.hold_piece_rect
    hold_current_piece
  end
end

def self.check_touch_left
  $inputs.mouse.inside_rect? $gg.touch_left_rect
end

def self.check_touch_right
  $inputs.mouse.inside_rect? $gg.touch_right_rect
end

def self.check_touch_down
  $inputs.mouse.inside_rect? $gg.touch_down_rect
end

def self.hold_current_piece
  return if $gg.hold_used_this_drop
  return if $gg.falling_blocks.empty?

  sound_hold
  current_piece = $gg.falling_blocks.first

  if $gg.held_piece.nil?
    $gg.held_piece = current_piece
    $gg.falling_blocks.clear
    spawn_falling_block
  else
    tmp = $gg.held_piece
    $gg.held_piece = current_piece
    $gg.falling_blocks.clear
    tmp.x = (GRID_WIDTH / 2).floor
    tmp.y = GRID_HEIGHT
    $gg.falling_blocks << tmp
  end

  $gg.hold_used_this_drop = true
end

def self.grid_index(x, y)
  y * GRID_WIDTH + x
end

def self.get_block(x, y)
  return nil if x < 0 || x >= GRID_WIDTH || y < 0 || y >= GRID_HEIGHT
  $gg.grid[grid_index(x, y)]
end

def self.set_block(x, y, block)
  if block && block.type == :water && block.frame_offset.nil?
    block.frame_offset = 0 # rand(WATER_FRAME_COUNT)
  end
  # if a block is at y GRID_HEIGHT and we're trying to set it - it's game over
  if y == GRID_HEIGHT
    $gg.game_over_at = $gg.clock
    $gg.next_scene = :tick_over
  else
    $gg.grid[grid_index(x, y)] = block
  end
end

def self.random_block
  refill_bag_if_empty
  type = $gg.bag.shift
  block = { type: type }

  if type == :water
    block.frame_offset = 0 # rand(WATER_FRAME_COUNT)
  end

  block
end

def self.check_trapped_resources
  trapped = []

  (0...GRID_HEIGHT-1).each do |y|
    (0...GRID_WIDTH).each do |x|
      block = get_block(x, y)
      above = get_block(x, y+1)
      next unless block && above

      if [:seed, :soil, :water, :sun, :brick].include?(block.type) &&
         above.type.to_s.start_with?("flower_")
        trapped << block
      end
    end
  end

  unless trapped.empty?
    $gg.blinking_shapes << {
      shape: :trapped_resources,
      blocks: trapped,
      timer: 70,
      visible: true,
      blink_interval: 20
    }
  end
end

def self.refill_bag_if_empty
  # $gg.bag = RESOURCE_TYPES.shuffle if $gg.bag.empty?
  pool = [:seed, :soil, :water] * 2
  pool += [:sun] * 1
  # check the unmatched resources, add another sun ?
  if resource_block_count > 7 && sun_block_count < 4
    # pool << :sun
    pool += [:sun] * 2
  end
  # Every 2 waves, add another brick (starting at wave 2)
  # brick_count = $gg.wave.idiv(2)   # wave 2 → 1, wave 4 → 2, etc.
  brick_count = 0
  brick_count += 1 if $gg.wave > 2
  brick_count += 1 if $gg.wave > 4
  brick_count -= 1 if $gg.wave > 6
  brick_count += 1 if $gg.wave > 7
  pool += [:brick] * brick_count
  # pool += [:brick] * $gg.wave if $gg.wave >= 2
  # pool += [:seed, :soil, :water] * 1
  $gg.bag = pool.shuffle if $gg.bag.empty?
end

def self.sun_block_count
  $gg.grid.count { |b| b && b.type == :sun }
end

def self.resource_block_count
  $gg.grid.count do |b|
    # b && !b.type.to_s.start_with?("flower_") && b.type != :sun
    # b && [:seed, :soil, :water, :brick].include?(b.type)
    b && [:seed, :soil, :water].include?(b.type)
  end
end

def self.spawn_falling_block
  $gg.falling_blocks << random_block.merge(x: (GRID_WIDTH / 2).floor, y: GRID_HEIGHT, player_controlled: true)
  $gg.cascade_multiplier = 1
end

def self.move_block_left
  fb = $gg.falling_blocks.first
  return unless fb
  new_x = fb.x - 1
  return if new_x < 0
  y_floor = fb.y.floor
  y_ceil = fb.y.ceil
  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)
  fb.x = new_x
end

def self.move_block_right
  fb = $gg.falling_blocks.first
  return unless fb
  new_x = fb.x + 1
  return if new_x >= GRID_WIDTH
  y_floor = fb.y.floor
  y_ceil = fb.y.ceil
  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)
  fb.x = new_x
end

def self.move_block_down
  landed_blocks = []

  $gg.falling_blocks.each do |fb|
    next_y = fb.y - 0.5
    next_y_floor = next_y.floor

    if next_y < 0 || get_block(fb.x, next_y_floor)
      fb.y = fb.y.floor
      set_block(fb.x, fb.y, fb)
      landed_blocks << fb
    else
      fb.y = next_y
    end
  end

  landed_blocks.each { |fb| $gg.falling_blocks.delete(fb) }

  check_for_flower_clusters unless landed_blocks.empty?
end

def self.any_loose_blocks?
  (0...GRID_HEIGHT).each do |y|
    (0...GRID_WIDTH).each do |x|
      block = get_block(x, y)
      next unless block
      below_y = y - 1
      return true if (below_y >= 0 && !get_block(x, below_y)) || (block.y % 1) == 0.5
    end
  end
  false
end

def self.move_loose_blocks_down
  return unless $gg.clock.zmod?(4)

  loose_blocks = []

  (0...GRID_HEIGHT).each do |y|
    (0...GRID_WIDTH).each do |x|
      b = get_block(x, y)
      next unless b
      below_y = b.y - 0.5
      next if below_y < 0
      below_floor = below_y.floor
      below_block = get_block(x, below_floor)
      loose_blocks << b if below_block.nil? || below_block.equal?(b)
    end
  end

  return if loose_blocks.empty?

  lowest_y = loose_blocks.map { |b| b.y }.min
  lowest_loose = loose_blocks.select { |b| b.y == lowest_y }

  lowest_loose.each do |b|
    old_y = b.y
    old_floor = old_y.floor
    new_y = [old_y - 0.5, 0.0].max
    new_floor = new_y.floor
    if new_floor < old_floor
      set_block(b.x, old_floor, nil)
      b.y = new_y
      set_block(b.x, new_floor, b)
    else
      b.y = new_y
    end
  end
end

def self.check_for_flower_clusters
  all_matches = []

  GRID_WIDTH.times do |x|
    GRID_HEIGHT.times do |y|
      ALL_SHAPES.each do |shape_name, patterns|
        patterns.each do |pattern|
          coords = pattern[:coords]
          expected_types = pattern[:types]

          blocks = coords.map { |dx, dy| get_block(x + dx, y + dy) }
          next if blocks.any?(&:nil?)

          block_types = blocks.map(&:type)
          match = expected_types.all? do |t|
            if t == :sun
              block_types.include?(:sun)
            else
              index = block_types.index(t)
              block_types.delete_at(index) if index
              !!index
            end
          end
          next unless match

          all_matches << { shape: shape_name, blocks: blocks }
        end
      end
    end
  end

  return if all_matches.empty?

  best_set = []
  best_count = 0

  best = { count: 0, set: [] }
  explore(all_matches, 0, [], [], best)
  best_set = best[:set]

  best_set.each do |match|
    blink_blocks = match[:blocks]

    if match[:shape].to_s.end_with?("_flowers")
      bricks = nearby_bricks(blink_blocks)
      blink_blocks += bricks
    end

    $gg.blinking_shapes << {
      shape: match[:shape],
      blocks: blink_blocks,
      timer: 70,
      visible: true,
      blink_interval: 20
    }
  end
end

def self.explore(matches, index, current_set, used_non_sun_blocks, best)
  if index >= matches.size
    total_non_sun = current_set.sum { |m| m[:blocks].count { |b| b.type != :sun } }
    if total_non_sun > best[:count]
      best[:count] = total_non_sun
      best[:set] = current_set.dup
    end
    return
  end

  match = matches[index]
  non_sun_blocks = match[:blocks].reject { |b| b.type == :sun }

  explore(matches, index + 1, current_set, used_non_sun_blocks, best)

  if (non_sun_blocks & used_non_sun_blocks).empty?
    explore(matches, index + 1,
            current_set + [match],
            used_non_sun_blocks + non_sun_blocks,
            best)
  end
end

def self.nearby_bricks(blocks)
  bricks = []
  blocks.each do |b|
    x, y = b.x, b.y
    # [[1,0],[-1,0],[0,1],[0,-1]].each do |dx, dy|
    [
      [ 1, 0], [-1, 0], [0,  1], [0, -1], # orthogonal
      [ 1, 1], [-1, 1], [1, -1], [-1, -1] # diagonals
    ].each do |dx, dy|
      nb = get_block(x+dx, y+dy)
      bricks << nb if nb && nb.type == :brick
    end
  end
  bricks.uniq
end

def self.water_frame_index_for(block)
  base = ($gg.clock / WATER_TICKS_PER_FRAME).floor
  offset = block.frame_offset.to_i
  (base + offset) % WATER_FRAME_COUNT
end

def self.path_for_block_sprite(block_type, block = nil)
  if block_type == :water && block
    frame = water_frame_index_for(block)
    return "sprites/water_#{frame}.png"
  end

  "sprites/#{block_type}.png"
end

def self.render_grid
  $gg.grid.each do |block|
    next unless block
    next if $gg.blinking_shapes.any? { |s| s.blocks.include?(block) }

    x = block.x * TILE_SIZE + GRID_OFFSET_X
    y = block.y * TILE_SIZE + GRID_OFFSET_Y

    if $gg.current_scene == :tick_over
      jitter_x = Math.sin($gg.wiggle_phase + block.x * 0.5) * 3
      jitter_y = Math.cos($gg.wiggle_phase + block.y * 0.5) * 3
      x += jitter_x
      y += jitter_y
    end

    sprite_path = path_for_block_sprite(block.type, block)

    if block.type == :water
      $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: :pixel, r: 0, g: 0, b: 200 }
    end

    if block.type == :sun
      render_sprite = { x: x, y: y, w: TILE_SIZE * 1.65, h: TILE_SIZE * 1.65, path: sprite_path, anchor_x: 0.2, anchor_y: 0.2 }
    else
      render_sprite = { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: sprite_path }
    end

    if block.angle
      render_sprite.angle = block.angle
    end

    $gg.tmp_sprites << render_sprite
  end

  $gg.falling_blocks.each do |fb|
    x = fb.x * TILE_SIZE + GRID_OFFSET_X
    y = fb.y * TILE_SIZE + GRID_OFFSET_Y
    sprite_path = path_for_block_sprite(fb.type, fb)
    if fb.type == :water
      $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: :pixel, r: 0, g: 0, b: 200 }
    end
    if fb.type == :sun
      $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE * 1.65, h: TILE_SIZE * 1.65, path: sprite_path, anchor_x: 0.2, anchor_y: 0.2 }
    else
      $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: sprite_path }
    end

    check_fb = $gg.falling_blocks.first
    if check_fb && check_fb[:player_controlled]
      col_x = fb.x * TILE_SIZE + GRID_OFFSET_X + TILE_SIZE / 2
      $gg.tmp_sprites << {
        x: col_x, y: GRID_OFFSET_Y,
        w: TILE_SIZE, h: GRID_PIXEL_HEIGHT,
        path: :pixel, r: 255, g: 255, b: 255, a: 2, anchor_x: 0.5
      }
    end
  end

  if $gg.blinking_shapes
    $gg.blinking_shapes.each do |blink|
      blink.timer -= 1
      blink.visible = !blink.visible if blink.timer % blink.blink_interval == 0

      shape_key =
        if blink.shape.to_s.end_with?("_flowers")
          blink.shape.to_s.chomp("_flowers").to_sym
        else
          blink.shape
        end

      color = BLINK_COLORS[shape_key] || { r: 255, g: 255, b: 255 }

      blink.blocks.each do |b|
        x = b.x * TILE_SIZE + GRID_OFFSET_X
        y = b.y * TILE_SIZE + GRID_OFFSET_Y

        if blink.visible
          sprite_path = path_for_block_sprite(b.type, b)
          if b.type == :water
            $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE,
                                 path: :pixel, r: 0, g: 0, b: 200 }
          end
          if b.type == :sun
            $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE * 1.65, h: TILE_SIZE * 1.65, path: sprite_path, anchor_x: 0.2, anchor_y: 0.2 }
          else
            $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: sprite_path }
          end
        else
          next if b.type == :brick
          $gg.tmp_sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE,
                               path: :pixel, **color }
        end
      end
    end

    cleared_shapes = []

    $gg.blinking_shapes.reject! do |blink|
      next false if blink.timer > 0

      blink.blocks.each do |b|
        set_block(b.x, b.y, nil)
        sound_block if blink.shape == :trapped_resources
      end

      $gg.total_score += (10 * $gg.cascade_multiplier * $gg.wave)
      $gg.cascade_multiplier *= 3
      $gg.total_score = 1000000 if $gg.total_score > 1000000

      if blink.shape
        flower_type = FLOWER_TYPES[blink.shape]
        if flower_type
          flower_block = lowest_leftmost_block(blink.blocks)
          angle = rand 360
          set_block(flower_block.x, flower_block.y,
            { type: flower_type, x: flower_block.x, y: flower_block.y, angle: angle })
          sound_shape
        end
      end

      $gg.loose_blocks = true
      $gg.pending_shape_check = true

      cleared_shapes << blink
      true
    end

    if cleared_shapes.any?
      total_blocks = cleared_shapes.sum { |s| s.blocks.size }
      $gg.camera_trauma = [0.2 + total_blocks * 0.05, 1.0].min
    end
  end

  draw_grid_outline
  draw_next_preview
  draw_score
  draw_shape_legend
  # draw_hold_piece_rect

  $outputs[:garden].sprites << $gg.tmp_sprites
  $gg.tmp_sprites.clear
end

def self.draw_hold_piece_rect
  $gg.tmp_sprites << $gg.hold_piece_rect.merge(path: :pixel, a: 128)
  # $gg.tmp_sprites << $gg.touch_right_rect.merge(path: :pixel, a: 128)
end

def self.draw_next_preview
  next_block = peek_next_block
  return unless next_block

  sprite_path = path_for_block_sprite(next_block[:type], next_block)

  if next_block[:type] == :water
    $gg.tmp_sprites << { x: 1070, y: 550, w: TILE_SIZE, h: TILE_SIZE, path: :pixel, r: 0, g: 0, b: 200 }
  end

  if next_block[:type] == :sun
    preview = { x: 1070, y: 550, w: TILE_SIZE * 1.65, h: TILE_SIZE * 1.65, path: sprite_path, anchor_x: 0.2, anchor_y: 0.2 }
  else
    preview = { x: 1070, y: 550, w: TILE_SIZE, h: TILE_SIZE, path: sprite_path }
  end

  $gg.tmp_sprites << preview

  $outputs[:garden].labels << {
    x: 1060, y: 680, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 175, b: 100, text: "Next"
  }

  $outputs[:garden].labels << {
    x: 120, y: 680, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 175, b: 100, text: "Hold"
  }

  if $gg.held_piece
    sprite_path = path_for_block_sprite($gg.held_piece[:type], $gg.held_piece)

    if $gg.held_piece[:type] == :water
      $gg.tmp_sprites << { x: 127, y: 550, w: TILE_SIZE, h: TILE_SIZE, path: :pixel, r: 0, g: 0, b: 200 }
    end

    if $gg.held_piece[:type] == :sun
      held_preview = { x: 127, y: 550, w: TILE_SIZE * 1.65, h: TILE_SIZE * 1.65, path: sprite_path, anchor_x: 0.2, anchor_y: 0.2 }
    else
      held_preview = { x: 127, y: 550, w: TILE_SIZE, h: TILE_SIZE, path: sprite_path }
    end
    $gg.tmp_sprites << held_preview
  end
end

def self.draw_score
  right_margin_start = 950
  right_margin_center = right_margin_start + (WIDTH - right_margin_start) / 2

  $outputs[:garden].labels << {
    x: right_margin_center, y: 460, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 175, b: 100, text: "Score", anchor_x: 0.5
  }
  $outputs[:garden].labels << {
    x: right_margin_center, y: 425, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 250, b: 100, text: "#{$gg.score.to_s.chars.reverse.each_slice(3).map(&:join).join(",").reverse}", anchor_x: 0.5
  }

  $outputs[:garden].labels << {
    x: right_margin_center, y: 360, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 175, b: 100, text: "High Score", anchor_x: 0.5
  }
  $outputs[:garden].labels << {
    x: right_margin_center, y: 325, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 250, b: 100, text: "#{$gg.high_score.to_s.chars.reverse.each_slice(3).map(&:join).join(",").reverse}", anchor_x: 0.5
  }

  $outputs[:garden].labels << {
    x: right_margin_center, y: 260, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 175, b: 100, text: "Wave", anchor_x: 0.5
  }
  $outputs[:garden].labels << {
    x: right_margin_center, y: 225, font: "fonts/IndieFlower-Regular.ttf", size_px: 64,
    r: 100, g: 250, b: 100, text: "#{$gg.wave}", anchor_x: 0.5
  }
end

def self.update_flower_rotations
  $gg.grid.each do |b|
    next unless b && b.angle
    b.angle = (b.angle + 1 ) % 360
  end
end

def self.peek_next_block
  refill_bag_if_empty
  { type: $gg.bag.first }
end

def self.lowest_leftmost_block(blocks)
  blocks.reduce(nil) do |best, b|
    if best.nil? || b.y < best.y || (b.y == best.y && b.x < best.x)
      b
    else
      best
    end
  end
end

def self.draw_grid_outline
  border_thickness = 14
  left   = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 175, b: 100 }
  right  = { x: GRID_OFFSET_X + GRID_PIXEL_WIDTH, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 175, b: 100 }
  bottom = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y - border_thickness, w: GRID_PIXEL_WIDTH + border_thickness * 2, h: border_thickness, path: :pixel, r: 100, g: 175, b: 100 }
  $gg.tmp_sprites << [left, right, bottom]
end

def self.screenshake
  return if $gg.camera_trauma == 0
  next_offset = 100 * $gg.camera_trauma**2
  $gg.camera_x_offset = next_offset.randomize(:sign, :ratio).round
  $gg.camera_y_offset = next_offset.randomize(:sign, :ratio).round
  $gg.camera_trauma *= 0.95
  if $gg.camera_trauma < 0.05
    $gg.camera_trauma = 0
    $gg.camera_x_offset = 0
    $gg.camera_y_offset = 0
  end
end

def self.tick_setup
  $audio[:music] ||= {
    input: 'sounds/in_the_hall_of_the_mountain_king.ogg',  # Filename
    x: 0.0, y: 0.0, z: 0.0,          # Relative position to the listener, x, y, z from -1.0 to 1.0
    gain: 0.5,                       # Volume (0.0 to 1.0)
    pitch: 1.0,                      # Pitch of the sound (1.0 = original pitch)
    paused: false,                   # Set to true to pause the sound at the current playback position
    looping: true                    # Set to true to loop the sound/music until you stop it
  }

  contents = $gtk.read_file "data/high_score.txt"
  if !contents
    $gtk.write_file "data/high_score.txt", "0"
  else
    $gg.high_score = contents.to_i
  end

  $gg.next_scene = :tick_title
end

def self.tick_title
  $outputs[:garden].labels << {
    x: 1260 / 2, y: 500, font: "fonts/IndieFlower-Regular.ttf", size_px: 256,
    r: 100, g: 250, b: 100, text: "Flower Garden", anchor_x: 0.5
  }

  falling_flowers

  return if $gg.clock < 30

  if $inputs.keyboard.key_down.r && $inputs.keyboard.key_held.h
    $gtk.write_file "data/high_score.txt", "0"
    $gg.high_score = 0
    $gg.total_score = 0
    $gtk.reset
  end

  if ($inputs.keyboard.key_up.truthy_keys.any? || $inputs.mouse.click)
    $gg.title_flowers.clear
    $gg.next_scene = :tick_game
  end
end

def self.tick_over
  $outputs[:garden].labels << {
    x: 1260 / 2, y: 500, font: "fonts/IndieFlower-Regular.ttf", size_px: 256,
    r: 100, g: 250, b: 100, text: "Game Over", anchor_x: 0.5
  }

  $gg.wiggle_phase += 0.1
  falling_flowers
  render_grid

  return if ($gg.clock - $gg.game_over_at) < 120

  if ($inputs.keyboard.key_up.truthy_keys.any? || $inputs.mouse.click)
    $gtk.reset
  end
end

def self.falling_flowers
  if $gg.clock % 5 == 0
    spawn_title_flower unless $gg.lost_focus
  end

  $gg.title_flowers.each do |f|
    f.y -= 0.05
    f.x += f.drift

    screen_tiles = WIDTH / TILE_SIZE
    if f.x < 0
      f.x = 0
      f.drift = f.drift.abs
    elsif f.x > screen_tiles
      f.x = screen_tiles
      f.drift = -f.drift.abs
    end

    f.angle = (f.angle + 1) % 360 if f.angle
  end

  $gg.title_flowers.reject! { |f| f.y * TILE_SIZE + GRID_OFFSET_Y < -TILE_SIZE }

  $gg.title_flowers.each do |f|
    x = f.x * TILE_SIZE + GRID_OFFSET_X
    y = f.y * TILE_SIZE + GRID_OFFSET_Y
    sprite_path = path_for_block_sprite(f.type, f)

    $gg.tmp_sprites << {
      x: x - 350 , y: y, w: TILE_SIZE, h: TILE_SIZE,
      path: sprite_path, angle: f.angle, a: 128
    }
  end

  $outputs[:garden].sprites << $gg.tmp_sprites
  $gg.tmp_sprites.clear
end

def self.check_wave_completion
  rows = count_flower_rows_from_bottom
  if rows >= $gg.wave
    $gg.wave += 1
    $gg.total_score += 1000
  end
end

def self.count_flower_rows_from_bottom
  count = 0
  (0...GRID_HEIGHT).each do |y|
    if row_full_of_flowers?(y)
      count += 1
    else
      break
    end
  end
  count
end

def self.row_full_of_flowers?(y)
  (0...GRID_WIDTH).all? do |x|
    block = get_block(x, y)
    block && block.type.to_s.start_with?("flower_")
  end
end

def self.spawn_title_flower
  flower_type = FLOWER_TYPES.values.sample

  x = rand(GAME_WIDTH / TILE_SIZE)
  y = GRID_HEIGHT + 2 + rand(11)

  block = {
    type: flower_type,
    x: x,
    y: y,
    angle: rand(360),
    drift: (rand * 0.1) - 0.05,
  }
  $gg.title_flowers << block
end

def self.draw_shape_legend
  x_offset = 95
  y_offset = 475
  size = 16

  FLOWER_TYPES.each_with_index do |(shape, flower_type), idx|
    coords = SHAPES[shape].first

    min_x = coords.map(&:first).min
    max_x = coords.map(&:first).max
    shape_width = max_x - min_x + 1

    center_x_offset = -((min_x + max_x) / 2.0)

    min_y = coords.map(&:last).min
    max_y = coords.map(&:last).max
    center_y_offset = -((min_y + max_y) / 2.0) + 0.55

    base_x = x_offset
    base_y = y_offset - idx * 75

    color = BLINK_COLORS[shape]
    coords.each do |dx, dy|
      adj_x = dx + center_x_offset
      adj_y = dy + center_y_offset
      $gg.tmp_sprites << {
        x: base_x + adj_x * size,
        y: base_y + adj_y * size,
        w: size,
        h: size,
        path: :pixel,
        **color
      }
    end

    $outputs[:garden].labels << {
      x: (base_x + 4 * size) - 5, y: base_y + size + 17, font: "fonts/IndieFlower-Regular.ttf",
      size_px: 32, r: 100, g: 175, b: 100,  text: "-"
    }

    sprite_path = path_for_block_sprite(flower_type)
    $gg.tmp_sprites << {
      x: base_x + 6 * size,
      y: base_y - 6,
      w: size * 3,
      h: size * 3,
      path: sprite_path
    }
  end
end

def self.game_has_lost_focus?
  return true if Kernel.tick_count < 30

  focus = !$inputs.keyboard.has_focus

  if focus != $gg.lost_focus
    if focus
      # putz "lost focus"
      $audio[:music] && $audio[:music].paused = true
    else
      # putz "gained focus"
      $audio[:music] && $audio[:music].paused = false
    end
  end
  # $gg.focus_color = focus ? { r: 225, g: 50, b: 50 } : { r: 50, g: 225, b: 50 }
  $gg.lost_focus = focus
end

$gtk.disable_framerate_warning!
$gtk.reset
