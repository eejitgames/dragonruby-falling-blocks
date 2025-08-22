WIDTH = 1280
HEIGHT = 720

GAME_WIDTH = 1260
GAME_HEIGHT = 700

ZOOM_WIDTH = (WIDTH / GAME_WIDTH).floor
ZOOM_HEIGHT = (HEIGHT / GAME_HEIGHT).floor
ZOOM = [ZOOM_WIDTH, ZOOM_HEIGHT].min

OFFSET_X = ((WIDTH - GAME_WIDTH * ZOOM) / 2).floor
OFFSET_Y = ((HEIGHT - GAME_HEIGHT * ZOOM) / 2).floor

ZOOMED_WIDTH = GAME_WIDTH * ZOOM
ZOOMED_HEIGHT = GAME_HEIGHT * ZOOM

GRID_WIDTH = 10
GRID_HEIGHT = 10
TILE_SIZE = 64

RESOURCE_TYPES = [:seed, :soil, :water, :sun]

GRID_PIXEL_WIDTH = GRID_WIDTH * TILE_SIZE
GRID_PIXEL_HEIGHT = GRID_HEIGHT * TILE_SIZE

GRID_OFFSET_X = ((GAME_WIDTH - GRID_PIXEL_WIDTH) / 2).floor
GRID_OFFSET_Y = ((GAME_HEIGHT - GRID_PIXEL_HEIGHT) / 2).floor

def self.boot args
  args.state = {}
  bootstrap
end

def self.reset args
  bootstrap
end

def self.tick args
  $outputs.background_color = [0, 0, 0]

  game_has_lost_focus?

  $outputs[:garden].w = GAME_WIDTH
  $outputs[:garden].h = GAME_HEIGHT
  $outputs[:garden].background_color = [0, 100, 0]

  $gg.mouse_position = {
    x: ($inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: ($inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1,
    h: 1
  }

  screenshake

  case $gg.current_scene
    when :setup then tick_setup
    when :title then tick_title
    when :game then tick_game
    when :over then tick_over
  end

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
    spawn_falling_block unless $gg.falling_block

    if $inputs.keyboard.key_down.left
      move_block_left
    elsif $inputs.keyboard.key_down.right
      move_block_right
    elsif $inputs.keyboard.key_down.down
      move_block_down
    end

    if $gg.clock % 30 == 0
      move_block_down
    end
  end

  render_grid
end

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
  { type: RESOURCE_TYPES.sample }
end

def self.spawn_falling_block
  $gg.falling_block = random_block.merge(x: (GRID_WIDTH / 2).floor, y: GRID_HEIGHT)
end

def self.move_block_left
  fb = $gg.falling_block
  return unless fb

  new_x = fb[:x] - 1
  return if new_x < 0

  y_floor = fb[:y].floor
  y_ceil = fb[:y].ceil

  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)

  fb[:x] = new_x
end

def self.move_block_right
  fb = $gg.falling_block
  return unless fb

  new_x = fb[:x] + 1
  return if new_x >= GRID_WIDTH

  y_floor = fb[:y].floor
  y_ceil = fb[:y].ceil

  return if get_block(new_x, y_floor) || get_block(new_x, y_ceil)

  fb[:x] = new_x
end

def self.move_block_down
  fb = $gg.falling_block
  return unless fb

  next_y = fb[:y] - 0.5
  next_y_floor = next_y.floor

  if next_y < 0 || get_block(fb[:x], next_y_floor)
    fb[:y] = fb[:y].floor
    set_block(fb[:x], fb[:y], fb)
    $gg.falling_block = nil
    check_for_flower_clusters
  else
    fb[:y] = next_y
  end
end

def self.render_grid
  $gg.grid.each_with_index do |block, i|
    next unless block

    x = block[:x] * TILE_SIZE + GRID_OFFSET_X
    y = block[:y] * TILE_SIZE + GRID_OFFSET_Y

    $outputs[:garden].sprites << {
      x: x, y: y,
      w: TILE_SIZE, h: TILE_SIZE,
      path: "sprites/#{block[:type]}.png"
    }
  end

  if $gg.falling_block
    fb = $gg.falling_block
    x = fb[:x] * TILE_SIZE + GRID_OFFSET_X
    y = fb[:y] * TILE_SIZE + GRID_OFFSET_Y

    $outputs[:garden].sprites << {
      x: x, y: y,
      w: TILE_SIZE, h: TILE_SIZE,
      path: "sprites/#{fb[:type]}.png"
    }
  end

  draw_grid_outline
end

def self.check_for_flower_clusters
end

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
    lost_focus: true
  }

  $gg.grid = Array.new(GRID_WIDTH * GRID_HEIGHT)
end

def self.draw_grid_outline
  border_thickness = 14

  left   = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 200, b: 100 }
  right  = { x: GRID_OFFSET_X + GRID_PIXEL_WIDTH, y: GRID_OFFSET_Y, w: border_thickness, h: GRID_PIXEL_HEIGHT, path: :pixel, r: 100, g: 200, b: 100 }
  # top    = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y + GRID_PIXEL_HEIGHT, w: GRID_PIXEL_WIDTH + border_thickness * 2, h: border_thickness, path: :pixel, r: 100, g: 200, b: 100 }
  bottom = { x: GRID_OFFSET_X - border_thickness, y: GRID_OFFSET_Y - border_thickness, w: GRID_PIXEL_WIDTH + border_thickness * 2, h: border_thickness, path: :pixel, r: 100, g: 200, b: 100 }

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

def self.tick_setup
  $gg.next_scene = :title
end

def self.tick_title
  $outputs[:garden].labels << {
    x: 1260 / 2, y: 500, font: "fonts/IndieFlower-Regular.ttf", size_px: 192, r: 100, g: 200, b: 100, text: "Walled Garden", anchor_x: 0.5
}

  return if $gg.clock < 30

  if $inputs.keyboard.key_down.r && $inputs.keyboard.key_held.h
    $gtk.write_file "data/high_score.txt", "0"
    $gg.high_score = 0
    $gg.total_score = 0
    $gtk.reset # $gtk.reset_next_time
  end

  if ($inputs.keyboard.key_up.truthy_keys.any? || $inputs.mouse.click)
    $gg.next_scene = :game
  end
end

def self.game_has_lost_focus?
  return true if Kernel.tick_count < 30

  focus = !$inputs.keyboard.has_focus

  if focus != $gg.lost_focus
    if focus
      # putz "lost focus"
    else
      # putz "gained focus"
    end
  end
  # $gg.focus_color = focus ? { r: 225, g: 50, b: 50 } : { r: 50, g: 225, b: 50 }
  $gg.lost_focus = focus
end

$gtk.disable_framerate_warning!
$gtk.reset