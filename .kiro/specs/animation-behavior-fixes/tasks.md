# Implementation Plan

- [x] 1. Fix player defeated animation horizontal movement



  - ✅ Modified defeated state physics in `scripts/entities/player.gd` to use horizontal cosine/sine movement instead of vertical sine wave
  - ✅ Added defeated_base_x and defeated_base_y variables to track starting position for oscillation
  - ✅ Replaced vertical sine wave with horizontal cosine movement using `cos(defeated_fly_time * 4.0)`
  - ✅ Ensured defeated_fly_direction is properly set when entering defeated state in `die()` function
  - ✅ Maintained existing screen boundary checking and respawn timer logic with screen clamping
  - ✅ Implemented smooth horizontal oscillation with 60px amplitude and position-based movement
  - ✅ **FIXED**: Removed vertical oscillation to achieve pure horizontal movement as specified in requirements
  - ✅ **VERIFIED**: Player defeated animation now uses horizontal-only movement with stable Y position
  - _Requirements: 1.1, 1.2, 1.4, 1.5 - ALL SATISFIED_

- [ ] 2. Implement bird-egg communication system
  - [ ] 2.1 Add bird reference tracking in enemy_base.gd
    - Add `associated_rescue_bird` variable to track spawned rescue bird
    - Modify `spawn_rescue_bird()` method to store reference to created bird
    - Add null checking and cleanup for bird references
    - _Requirements: 2.4, 2.5_
  
  - [ ] 2.2 Enhance rescue bird with speed control
    - Add `base_speed`, `speed_multiplier`, and `is_speeding_up` variables to `scripts/entities/rescue_bird.gd`
    - Modify movement calculation to use `base_speed * speed_multiplier`
    - Add `speed_up()` method to increase speed when egg is collected
    - _Requirements: 3.2, 3.3_
  
  - [ ] 2.3 Update egg collection to handle active birds
    - Modify `collect_egg()` method in `scripts/entities/enemy_base.gd` to check for `associated_rescue_bird`
    - When bird exists, call bird's `speed_up()` method instead of letting bird disappear
    - Set bird's `egg_was_collected` flag to true
    - _Requirements: 2.4, 2.5_

- [ ] 3. Implement bird screen traversal completion
  - [ ] 3.1 Add traversal completion logic to rescue bird
    - Modify `_physics_process()` in `scripts/entities/rescue_bird.gd` to continue movement even when egg is collected
    - Add screen boundary detection for bird cleanup
    - Implement smooth speed transition when `speed_up()` is called
    - _Requirements: 3.4, 3.5_
  
  - [ ] 3.2 Handle bird cleanup and edge cases
    - Add proper cleanup when bird reaches screen edge
    - Handle case where target_enemy becomes invalid during speed-up
    - Ensure bird doesn't get stuck at screen boundaries
    - _Requirements: 3.4, 3.5_

- [ ]* 4. Add comprehensive testing
  - [ ]* 4.1 Create unit tests for defeated animation
    - Test horizontal cosine/sine movement calculations
    - Verify defeated_fly_direction handling
    - Test screen boundary constraints
    - _Requirements: 1.1, 1.2, 1.5_
  
  - [ ]* 4.2 Create integration tests for bird-egg system
    - Test normal egg collection (before bird spawns)
    - Test egg collection with active bird (speed-up scenario)
    - Test bird traversal completion after speed-up
    - Test edge cases (bird at various screen positions)
    - _Requirements: 2.1, 2.4, 2.5, 3.2, 3.4, 3.5_