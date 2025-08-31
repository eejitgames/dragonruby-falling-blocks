###############################################
# FLOWER GARDEN - Falling Block Puzzle Game
# Built with DragonRuby GTK
#
# Core idea: Like Tetris, but with resource blocks
# (seed, soil, water, sun, rock). When certain
# patterns (shapes) form, they bloom into flowers.
###############################################

############################
# --- GLOBAL CONSTANTS ---
############################

# Window and game rendering dimensions
WIDTH       = 1280
HEIGHT      = 720
GAME_WIDTH  = 1260
GAME_HEIGHT = 700

# Scaling (zoom) so the grid fits the game area
ZOOM_WIDTH   = (WIDTH / GAME_WIDTH).floor
ZOOM_HEIGHT  = (HEIGHT / GAME_HEIGHT).floor
ZOOM         = [ZOOM_WIDTH, ZOOM_HEIGHT].min
OFFSET_X     = ((WIDTH - GAME_WIDTH * ZOOM) / 2).floor
OFFSET_Y     = ((HEIGHT - GAME_HEIGHT * ZOOM) / 2).floor
ZOOMED_WIDTH  = GAME_WIDTH * ZOOM
ZOOMED_HEIGHT = GAME_HEIGHT * ZOOM

# Grid (playfield) settings
GRID_WIDTH  = 10
GRID_HEIGHT = 10
TILE_SIZE   = 64

# Types of blocks that can fall
#RESOURCE_TYPES = [:seed, :soil, :water, :sun, :rock]
RESOURCE_TYPES = [:seed, :soil, :water, :sun, :rock]

# Pixel size of the grid
GRID_PIXEL_WIDTH  = GRID_WIDTH * TILE_SIZE
GRID_PIXEL_HEIGHT = GRID_HEIGHT * TILE_SIZE

# Grid’s offset (so it’s centered in the play area)
GRID_OFFSET_X = ((GAME_WIDTH - GRID_PIXEL_WIDTH) / 2).floor
GRID_OFFSET_Y = ((GAME_HEIGHT - GRID_PIXEL_HEIGHT) / 2).floor

SCENES = {
  setup: -> { tick_setup },
  title: -> { tick_title },
  game:  -> { tick_game },
  over:  -> { tick_over }
}

##################################
# --- SHAPE DEFINITIONS ---
##################################

# General shapes: position only matters (not block type).
# Require one of each resource (except rock).
SHAPES = {
  o_shape: [ [[0,0],[1,0],[0,1],[1,1]] ],
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
=begin
# Fixed shapes: require specific block *types* in exact places
FIXED_SHAPES = {
  three_seeds: [
    { coords: [[0,0],[1,0],[2,0]], types: [:seed, :seed, :seed] },
    { coords: [[0,0],[0,1],[0,2]], types: [:seed, :seed, :seed] }
  ],
  plus_soil_water: [
    {
      coords: [[0,0],[0,-1],[0,1],[-1,0],[1,0]],
      types: [:soil, :water, :water, :water, :water]
    }
  ]
}
=end
# Each shape corresponds to a flower type
FLOWER_TYPES = {
  o_shape: :flower_daisy,
  j_shape: :flower_rose,
  l_shape: :flower_tulip,
  t_shape: :flower_sunflower,
  i_shape: :flower_orchid,
  s_shape: :flower_lily,
  z_shape: :flower_peony
}

# Flower shapes: Same geometry, but filled with flowers
FLOWER_SHAPES = SHAPES.transform_keys do |shape_name|
  :"#{shape_name}_flowers"
end.transform_values do |orientations|
  orientations.map do |coords|
    FLOWER_TYPES.map do |_, flower_type|
      { coords: coords, types: Array.new(coords.size, flower_type) }
    end
  end.flatten
end

# Combine all shape definitions into one lookup table (there should be no key duplicates)
ALL_SHAPES = SHAPES.transform_values do |orientations|
  orientations.map { |coords| { coords: coords, types: RESOURCE_TYPES.reject { |t| t == :rock } } }
end.merge(FLOWER_SHAPES) #.merge(FIXED_SHAPES)

############################
# --- GAME LOOP METHODS ---
############################

def self.boot args
  args.state = {}
  bootstrap
end

def self.reset args
  bootstrap
end

# Main tick: runs every frame
def self.tick args
  $outputs.background_color = [0, 0, 0]

  game_has_lost_focus?

  # Create a separate render target for the garden playfield
  $outputs[:garden].w = GAME_WIDTH
  $outputs[:garden].h = GAME_HEIGHT
  $outputs[:garden].background_color = [25, 50, 25]

  # Convert mouse position into grid coordinates
  $gg.mouse_position = {
    x: ($inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: ($inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1,
    h: 1
  }

  # Handle camera shake effect
  screenshake

  # Scene manager: switch between setup, title, gameplay, and game over
  SCENES[$gg.current_scene].call

  # Render scaled garden output onto the screen
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

  # Handle scene transitions
  $gg.current_scene = $gg.next_scene if $gg.current_scene != $gg.next_scene
end

############################
# --- GAMEPLAY LOGIC ---
############################

def self.tick_game
  unless $gg.lost_focus
    # Check if blocks are unstable and should fall
    if any_loose_blocks?
      $gg.loose_blocks = :true
    else
      # Check for flower clusters if pending
      if $gg.pending_shape_check
        check_for_flower_clusters
        $gg.pending_shape_check = false
      end
      $gg.loose_blocks = nil
    end

    # Spawn a new falling block if the grid is clear
    unless $gg.loose_blocks
      spawn_falling_block if $gg.falling_blocks.empty? unless $gg.blinking_shapes.any?
    end

    # Move unstable blocks downward
    move_loose_blocks_down if $gg.loose_blocks

    # Handle keyboard input for player control
    handle_block_input
  end

  # Draw all blocks (fixed + falling + blinking)
  render_grid

  update_flower_rotations if $gg.clock % 10 == 0
end

# Handle left/right/down block movement with cooldowns
def self.handle_block_input
  # LEFT
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

  # RIGHT
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

  # DOWN
  move_block_down if $inputs.keyboard.down

  # Automatic downward movement every 30 ticks
  move_block_down if $gg.clock % 30 == 0
end

############################
# --- GRID HELPERS ---
############################

def self.grid_index(x, y)
  y * GRID_WIDTH + x
end

def self.get_block(x, y)
  return nil if x < 0 || x >= GRID_WIDTH || y < 0 || y >= GRID_HEIGHT
  $gg.grid[grid_index(x, y)]
end

def self.set_block(x, y, block)
  $gg.grid[grid_index(x, y)] = block
end

def self.random_block
  refill_bag_if_empty
  type = $gg.bag.shift
  { type: type }
end

def self.refill_bag_if_empty
  $gg.bag = RESOURCE_TYPES.shuffle if $gg.bag.empty?
end

def self.spawn_falling_block
  $gg.falling_blocks << random_block.merge(x: (GRID_WIDTH / 2).floor, y: GRID_HEIGHT)
end

############################
# --- BLOCK MOVEMENT ---
############################

def self.move_block_left
  fb = $gg.falling_blocks.first
  return unless fb
  new_x = fb[:x] - 1
  return if new_x < 0
  y_floor = fb[:y].floor
  y_ceil = fb[:y].ceil
  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)
  fb[:x] = new_x
end

def self.move_block_right
  fb = $gg.falling_blocks.first
  return unless fb
  new_x = fb[:x] + 1
  return if new_x >= GRID_WIDTH
  y_floor = fb[:y].floor
  y_ceil = fb[:y].ceil
  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)
  fb[:x] = new_x
end

def self.move_block_down
  landed_blocks = []

  $gg.falling_blocks.each do |fb|
    next_y = fb[:y] - 0.5
    next_y_floor = next_y.floor

    if next_y < 0 || get_block(fb[:x], next_y_floor)
      fb[:y] = fb[:y].floor
      set_block(fb[:x], fb[:y], fb)
      landed_blocks << fb
    else
      fb[:y] = next_y
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
      return true if (below_y >= 0 && !get_block(x, below_y)) || (block[:y] % 1) == 0.5
    end
  end
  false
end

def self.move_loose_blocks_down
  return unless $gg.clock.zmod?(6)

  loose_blocks = []

  (0...GRID_HEIGHT).each do |y|
    (0...GRID_WIDTH).each do |x|
      b = get_block(x, y)
      next unless b
      below_y = b[:y] - 0.5
      next if below_y < 0
      below_floor = below_y.floor
      below_block = get_block(x, below_floor)
      loose_blocks << b if below_block.nil? || below_block.equal?(b)
    end
  end

  return if loose_blocks.empty?

  lowest_y = loose_blocks.map { |b| b[:y] }.min
  lowest_loose = loose_blocks.select { |b| b[:y] == lowest_y }

  lowest_loose.each do |b|
    old_y = b[:y]
    old_floor = old_y.floor
    new_y = [old_y - 0.5, 0.0].max
    new_floor = new_y.floor
    if new_floor < old_floor
      set_block(b[:x], old_floor, nil)
      b[:y] = new_y
      set_block(b[:x], new_floor, b)
    else
      b[:y] = new_y
    end
  end
end

############################
# --- FLOWER DETECTION ---
############################

def self.check_for_flower_clusters
  GRID_WIDTH.times do |x|
    GRID_HEIGHT.times do |y|
      ALL_SHAPES.each do |shape_name, patterns|
        patterns.each do |pattern|
          coords = pattern[:coords]
          expected_types = pattern[:types]

          blocks = coords.map { |dx, dy| get_block(x + dx, y + dy) }
          next if blocks.any?(&:nil?)

          actual_types = blocks.map { |b| b[:type] }

          match = if expected_types.is_a?(Array) && expected_types.all? { |t| RESOURCE_TYPES.include?(t) } && expected_types.size == actual_types.size
                    actual_types.sort == expected_types.sort
                  else
                    actual_types == expected_types
                  end

          next unless match

          unless $gg.blinking_shapes.any? { |s| (s[:blocks] & blocks).any? }
            if shape_name.to_s.end_with?("_flowers")
              # This is a flower shape — include nearby rocks
              all_blocks = blocks.dup + nearby_rocks(blocks)
              $gg.blinking_shapes << {
                shape: shape_name,
                blocks: all_blocks,
                timer: 60,
                visible: true,
                blink_interval: 10
              }
            else
              # Normal resource shape — no rocks affected
              $gg.blinking_shapes << {
                shape: shape_name,
                blocks: blocks.dup,
                timer: 60,
                visible: true,
                blink_interval: 10
              }
            end
          end
=begin
          # Prevent duplicate blinking shapes
          unless $gg.blinking_shapes.any? { |s| (s[:blocks] & blocks).any? }
            $gg.blinking_shapes << {
              shape: shape_name,
              blocks: blocks.dup,
              timer: 60,
              visible: true,
              blink_interval: 10
            }
          end
=end
        end
      end
    end
  end
end

def self.nearby_rocks(blocks)
  rocks = []
  blocks.each do |b|
    x, y = b[:x], b[:y]
    [[1,0],[-1,0],[0,1],[0,-1]].each do |dx, dy|
      nb = get_block(x+dx, y+dy)
      rocks << nb if nb && nb[:type] == :rock
    end
  end
  rocks.uniq
end

############################
# --- RENDERING ---
############################

def self.render_grid
  # Render fixed blocks
  $gg.grid.each do |block|
    next unless block
    next if $gg.blinking_shapes.any? { |s| s[:blocks].include?(block) }

    x = block[:x] * TILE_SIZE + GRID_OFFSET_X
    y = block[:y] * TILE_SIZE + GRID_OFFSET_Y

    render_sprite = { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: "sprites/#{block[:type]}.png" }
    
    if block[:angle]
      render_sprite[:angle] = block[:angle]
      #render_sprite[:angle_anchor_x] = 0.5
      #render_sprite[:angle_anchor_y] = 0.5
    end

    $outputs[:garden].sprites << render_sprite
  end

  # Render falling blocks
  $gg.falling_blocks.each do |fb|
    x = fb[:x] * TILE_SIZE + GRID_OFFSET_X
    y = fb[:y] * TILE_SIZE + GRID_OFFSET_Y
    $outputs[:garden].sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: "sprites/#{fb[:type]}.png" }
  end

  # Handle blinking shapes (about to be cleared into flowers)
  if $gg.blinking_shapes
    $gg.blinking_shapes.each do |blink|
      blink[:timer] -= 1
      blink[:visible] = !blink[:visible] if blink[:timer] % blink[:blink_interval] == 0

      if blink[:visible]
        blink[:blocks].each do |b|
          x = b[:x] * TILE_SIZE + GRID_OFFSET_X
          y = b[:y] * TILE_SIZE + GRID_OFFSET_Y
          $outputs[:garden].sprites << { x: x, y: y, w: TILE_SIZE, h: TILE_SIZE, path: "sprites/#{b[:type]}.png" }
        end
      end
    end

    # Clear shapes when timer expires
    $gg.blinking_shapes.reject! do |blink|
      next false if blink[:timer] > 0

      blink[:blocks].each { |b| set_block(b[:x], b[:y], nil) }
      $gg.score += 10
      $gg.camera_trauma = 0.5

      # Place flower at lowest-left block
      if blink[:shape]
        flower_type = FLOWER_TYPES[blink[:shape]]
        if flower_type
          flower_block = lowest_leftmost_block(blink[:blocks])
          angle = rand 360
          set_block(flower_block[:x], flower_block[:y], { type: flower_type, x: flower_block[:x], y: flower_block[:y], angle: angle })
        end
      end

      $gg.loose_blocks = true
      $gg.pending_shape_check = true
      true
    end
  end

  draw_grid_outline
end

def self.update_flower_rotations
  $gg.grid.each do |b|
    next unless b && b[:angle]
    b[:angle] = (b[:angle]  + 1 ) % 360
  end
end

def self.lowest_leftmost_block(blocks)
  blocks.reduce(nil) do |best, b|
    if best.nil? || b[:y] < best[:y] || (b[:y] == best[:y] && b[:x] < best[:x])
      b
    else
      best
    end
  end
end

############################
# --- GAME STATE HELPERS ---
############################

def self.bootstrap
  $gg = {
    current_scene: :setup,
    next_scene: :setup,
    camera_trauma: 0.5,
    camera_x_offset: 0,
    camera_y_offset: 0,
    score: 0,
    high_score: 0,
    total_score: 0,
    clock: 0,
    lost_focus: true,
    bag: [],
    blinking_shapes: [],
    falling_blocks: [],
    moved_loose_blocks: [],
    loose_blocks: nil,
    left_moved_at: 0,
    left_pending: false,
    left_cooldown: 8,
    right_moved_at: 0,
    right_pending: false,
    right_cooldown: 8
  }
  $gg.grid = Array.new(GRID_WIDTH * GRID_HEIGHT)
end

def self.draw_grid_outline
  border_thickness = 14
  left   = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 175, b: 100 }
  right  = { x: GRID_OFFSET_X + GRID_PIXEL_WIDTH, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 175, b: 100 }
  bottom = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y - border_thickness, w: GRID_PIXEL_WIDTH + border_thickness * 2, h: border_thickness, path: :pixel, r: 100, g: 175, b: 100 }
  $outputs[:garden].sprites << [left, right, bottom]
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

############################
# --- SCENES ---
############################

def self.tick_setup
  $gg.next_scene = :title
end

def self.tick_title
  $outputs[:garden].labels << {
    x: 1260 / 2, y: 500, font: "fonts/IndieFlower-Regular.ttf", size_px: 256,
    r: 100, g: 175, b: 100, text: "Flower Garden", anchor_x: 0.5
  }

  return if $gg.clock < 30

  # Reset high score if h is held down and r is pressed
  if $inputs.keyboard.key_down.r && $inputs.keyboard.key_held.h
    $gtk.write_file "data/high_score.txt", "0"
    $gg.high_score = 0
    $gg.total_score = 0
    $gtk.reset
  end

  # Start game on any key or mouse click
  if ($inputs.keyboard.key_up.truthy_keys.any? || $inputs.mouse.click)
    $gg.next_scene = :game
  end
end

def self.game_has_lost_focus?
  return true if Kernel.tick_count < 30

  focus = !$inputs.keyboard.has_focus
  $gg.lost_focus = focus
end

$gtk.disable_framerate_warning!
$gtk.reset
