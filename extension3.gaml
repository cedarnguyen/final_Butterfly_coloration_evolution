

model Butterfly_Coloration_Evolution

global {
	
    int grid_size <- 100;
    int initial_butterflies <- 30;
    int initial_predators <- 10;
    int initial_food <- 15;
    float initial_energy <- 100;
    float predation_intensity <- 0.5 min: 0.1 max: 1.0 step: 0.1;
    float reproduction_rate <- 0.1 min: 0.1 max: 1.0 step: 0.1;
	
    int count_black <- 0;
    int count_white <- 0;
    int count_gray <- 0;
    int cycle_counter <- 0;
    float patch_transition_speed <- 0.05 min: 0.01 max: 0.2 step: 0.01;


    string most_represented_color <- "";
    
    list<int> black_population <- [];
    list<int> white_population <- [];
    list<int> gray_population <- [];
    list<float> camouflage_effectiveness <- [];
    list<int> eggs_hatched <- [];
    list<int> eggs_failed <- [];
    list<int> predation_attempts <- [];
    list<int> successful_hunts <- [];
	list<int> black_hunts <- [];
    list<int> white_hunts <- [];
    list<int> gray_hunts <- [];
    
    list<int> black_patches <- [];
    list<int> white_patches <- [];
    list<int> gray_patches <- [];

    init {
        create butterflies number: initial_butterflies;
        create predators number: initial_predators;
        create food number: initial_food;
    }

//    reflex update_population {
//        count_black <- length(butterflies where (each.color = "Black"));
//        count_white <- length(butterflies where (each.color = "White"));
//        count_gray <- length(butterflies where (each.color = "Gray"));
//    }

		reflex update_population {
		    count_black <- length(butterflies where (each.color = "Black"));
		    count_white <- length(butterflies where (each.color = "White"));
		    count_gray <- length(butterflies where (each.color = "Gray"));
		
		    // Determine the most represented color
		    if (count_black >= count_white and count_black >= count_gray) {
		        most_represented_color <- "Black";
		    } else if (count_white >= count_black and count_white >= count_gray) {
		        most_represented_color <- "White";
		    } else {
		        most_represented_color <- "Gray";
		    }
		}


reflex track_cycles {
    cycle_counter <- cycle_counter + 1;
    if (cycle_counter - (int(cycle_counter / 30) * 30) = 0) {
        do regenerate_food;
    }
}


   reflex track_statistics {
        // Track populations
        black_population <- black_population + [length(butterflies where (each.color = "Black"))];
        white_population <- white_population + [length(butterflies where (each.color = "White"))];
        gray_population <- gray_population + [length(butterflies where (each.color = "Gray"))];

        // Track camouflage effectiveness
        int total_encounters <- length(butterflies where (length(predators at_distance 1.0) > 0));
        int survived <- total_encounters - length(butterflies where (each.is_alive = false));
        camouflage_effectiveness <- camouflage_effectiveness + [total_encounters > 0 ? float(survived) / total_encounters : 0];

        // Track eggs
        int hatched <- length(eggs where (each.hatching_cycle <= cycle and rnd(1.0) <= 0.9));
        eggs_hatched <- eggs_hatched + [hatched];
        eggs_failed <- eggs_failed + [length(eggs) - hatched];

        // Track hunting success
        int attempts <- length(predators where (each.hunt_probability > 0));
        int successes <- length(butterflies where (each.is_alive = false and length(predators at_distance 1.0) > 0));
        predation_attempts <- predation_attempts + [attempts];
        successful_hunts <- successful_hunts + [successes];
        
        
    int black_hunted <- length(butterflies where (each.color = "Black" and not each.is_alive));
    int white_hunted <- length(butterflies where (each.color = "White" and not each.is_alive));
    int gray_hunted <- length(butterflies where (each.color = "Gray" and not each.is_alive));

    black_hunts <- black_hunts + [black_hunted];
    white_hunts <- white_hunts + [white_hunted];
    gray_hunts <- gray_hunts + [gray_hunted];
    }
    
    reflex track_environment_colors {
    int black_count <- length(environment_grid where (each.cell_color = 0));
    int white_count <- length(environment_grid where (each.cell_color = 1));
    int gray_count <- length(environment_grid where (each.cell_color = 2));

    black_patches <- black_patches + [black_count];
    white_patches <- white_patches + [white_count];
    gray_patches <- gray_patches + [gray_count];
}

    action regenerate_food {
        int current_food_count <- length(food);
        int food_to_generate <- initial_food - current_food_count;

        if (food_to_generate > 0) {
            create food number: food_to_generate;
        }
    }
}


grid environment_grid height: grid_size width: grid_size neighbors: 8 {
    int cell_color <- rnd(3); // 0 = Black, 1 = White, 2 = Gray
    bool is_free <- true;
    bool has_food <- false;

    init {
        cell_color <- rnd(3);
    }

    reflex update_color {
        if (rnd(1.0) < patch_transition_speed) {
            cell_color <- rnd(3); // Randomly change the color
        }
    }

    aspect plotGrid {
        if (has_food) {
            draw square(1) color: #green;
        } else if (cell_color = 0) {
            draw square(1) color: #black;
        } else if (cell_color = 1) {
            draw square(1) color: #white;
        } else if (cell_color = 2) {
            draw square(1) color: #gray;
        }
    }
}


species food {
    environment_grid food_loc;
    int lifespan <- 30; // Lifespan of the food
    bool is_regenerated <- false;

    init {
        food_loc <- one_of(environment_grid where (each.is_free = true));
        if (food_loc != nil) {
            food_loc.has_food <- true;
        }
        location <- food_loc.location;
    }

    reflex decay when: lifespan <= 0 {
        if (food_loc != nil) {
            food_loc.has_food <- false;
        }
        do die;
    }

    reflex regenerate when: lifespan <= (30 * 0.75) and not is_regenerated {
        // Regenerate food in a new location
        environment_grid new_loc <- one_of(environment_grid where (each.is_free = true and not each.has_food));
        if (new_loc != nil) {
            new_loc.has_food <- true;
            food_loc <- new_loc; // Update the food location
            location <- new_loc.location;
            is_regenerated <- true;
        }
    }

    reflex age_food {
        lifespan <- lifespan - 1;
    }

    aspect food_char {
        draw square(2) color: #green;
    }
}


species creature {
    environment_grid my_loc;
    float energy <- initial_energy;

    init {
        my_loc <- one_of(environment_grid where (each.is_free = true));
        if (my_loc = nil) {
            my_loc <- first(environment_grid);
        }
        my_loc.is_free <- false;
    }

    reflex move {
        environment_grid next_loc <- one_of(my_loc.neighbors where (each.is_free = true));
        if (next_loc != nil) {
            my_loc.is_free <- true;
            next_loc.is_free <- false;
            my_loc <- next_loc;
        }
        location <- my_loc.location;
    }

    action move_to_cell(environment_grid new_loc) {
        if (my_loc != nil) {
            my_loc.is_free <- true;
        }
        new_loc.is_free <- false;
        my_loc <- new_loc;
        location <- new_loc.location;
    }

    reflex energy_loss {
        energy <- energy - 1;
    }

    reflex death when: energy <= 0.0 {
        do die;
    }
}

species butterflies parent: creature {
    string color <- one_of(["Black", "White", "Gray"]);
    bool is_alive <- true;
    int age <- 0;
    int max_lifetime <- 30; // Base lifetime
    int eggs_laid <- 0; // Track the number of eggs laid
    int max_eggs <- 1; // Maximum number of eggs a butterfly can lay
    float env_color <- 0;
    float camouflage_score <- 0.0;
    environment_grid prev_loc <- nil;

    init {
        my_loc <- one_of(environment_grid where (each.is_free = true));
        if (my_loc = nil) {
            my_loc <- first(environment_grid);
        }
        prev_loc <- my_loc;
        my_loc.is_free <- false;
    }

    reflex age_and_death when: is_alive {
        age <- age + 1;
        if (age >= max_lifetime) {
            is_alive <- false;
            do die;
        }
    }

    reflex move_and_search_food when: is_alive {
        environment_grid food_loc <- one_of(my_loc.neighbors where (each.has_food = true));
        if (food_loc != nil) {
            do move_to_cell(food_loc);
            energy <- energy + 20; // Gain energy from food
            food_loc.has_food <- false;

            // Extend lifetime and allow laying one more egg
            max_lifetime <- max_lifetime + 10;
            max_eggs <- max_eggs + 1;
        } else {
            environment_grid next_loc <- one_of(my_loc.neighbors where (each.is_free = true));
            if (next_loc != nil) {
                prev_loc <- my_loc;
                do move_to_cell(next_loc);
            }
        }
    }

    reflex lay_egg when: is_alive and eggs_laid < max_eggs {
        if (prev_loc != nil and prev_loc.is_free) {
            create eggs number: 1 with: [
                parent_color::color,
                hatching_cycle::(cycle + 10 #cycles),
                egg_loc::prev_loc
            ];
            prev_loc.is_free <- false;
            eggs_laid <- eggs_laid + 1;
        }
    }

    reflex update_env_color when: is_alive {
        env_color <- float(my_loc.cell_color);
    }

reflex compute_camouflage when: is_alive {
    if (color = "Black") {
        if (env_color = 0) {
            camouflage_score <- 0.9;
        } else if (env_color = 1) {
            camouflage_score <- 0.1;
        } else {
            camouflage_score <- 0.5;
        }
    } else if (color = "White") {
        if (env_color = 1) {
            camouflage_score <- 0.9;
        } else if (env_color = 0) {
            camouflage_score <- 0.1;
        } else {
            camouflage_score <- 0.5;
        }
    } else if (color = "Gray") {
        if (env_color = 2) {
            camouflage_score <- 0.7;
        } else {
            camouflage_score <- 0.5;
        }
    }
}


    reflex avoid_predation when: is_alive {
        if (length(predators at_distance 1.0) > 0) {
            if (rnd(1.0) > camouflage_score * (1 - predation_intensity)) {
                is_alive <- false;
                do die;
            }
        }
    }

    aspect butterfly_char {
        if (color = "Black") {
            draw circle(1) color: #lightblue;
        } else if (color = "White") {
            draw circle(1) color: #mediumblue;
        } else if (color = "Gray") {
            draw circle(1) color: #darkblue;
        }
    }
}

species eggs {
    string parent_color <- "";
    int hatching_cycle <- 0 #cycles;
    environment_grid egg_loc;

    reflex hatch when: cycle >= hatching_cycle {
        if (rnd(1.0) <= 0.9) { // 85% chance of hatching
            create butterflies number: 1 with: [color::parent_color, my_loc::egg_loc];
            egg_loc.is_free <- false;
        } else {
            egg_loc.is_free <- true; // Egg does not hatch, free the cell
        }
        do die;
    }

    aspect egg_char {
        draw ellipse(0.5, 0.8) color: #yellow;
    }
}

species predators parent: creature {
    float detection_range <- 5.0; // Detection range for finding butterflies
    float hunt_probability <- 0.7; // Base probability of successful predation
    float energy_gain <- 50.0; // Energy gained from hunting a butterfly
	float predation_intensity <- 0.5 min: 0.1 max: 1.0 step: 0.1;
reflex hunt {
    // Adjust instinct when energy is low
    float instinct_boost <- 1.0;
    if (energy < 50) {
        instinct_boost <- 3; // Boost detection range and hunt probability
    }

    // Collect all nearby butterflies within the boosted detection range
    list<butterflies> nearby_butterflies <- butterflies at_distance (detection_range * instinct_boost) where (each.is_alive);

    if (!empty(nearby_butterflies)) {
        // Initialize variables for selecting the best target
        butterflies target <- nil;
        float min_score <- 99999.0; // Replace infinity with a large value

        // Loop through the nearby butterflies using index-based iteration
        loop i from: 0 to: length(nearby_butterflies) - 1 {
            butterflies b <- nearby_butterflies[i]; // Get the butterfly at index i

            // Calculate distance to the butterfly
            float dist <- distance_to(b.my_loc.location, my_loc.location);

            // Calculate weighted score based on camouflage and distance
            float score <- b.camouflage_score * dist;

            // Update target if this butterfly has a lower score
            if (score < min_score) {
                target <- b;
                min_score <- score;
            }
        }

        // Engage with the selected target
        if (target != nil) {
            ask target {
                if (is_alive) {
                    float adjusted_probability <- myself.predation_intensity * (1 - camouflage_score);
                    if (rnd(1.0) <= adjusted_probability) {
                        // Successful hunt: Reset predator's energy to full and kill the target
                        myself.energy <- initial_energy;
                        is_alive <- false;
                        do die;
                    }
                }
            }

            // Move toward the target if still alive
            if (target.is_alive) {
                do move_to_cell(target.my_loc);
            }
        }
    } else {
        // Random movement if no butterflies are nearby
        environment_grid random_loc <- one_of(my_loc.neighbors where (each.is_free));
        if (random_loc != nil) {
            do move_to_cell(random_loc);
        }
    }
}


    reflex energy_decay {
        energy <- energy - 1; // Predators lose energy over time
    }

    reflex death when: energy <= 0.0 {
        do die;
    }

    aspect predator_char {
        draw triangle(2) color: #red;
    }
}



experiment butterfly_gui type: gui {
    parameter "Predation Intensity" var: predation_intensity category: "Environment";
    parameter "Reproduction Rate" var: reproduction_rate category: "Population";

    output {
        display environment {
            species environment_grid aspect: plotGrid;
            species butterflies aspect: butterfly_char;
            species predators aspect: predator_char;
            species eggs aspect: egg_char;
            species food aspect: food_char;
        }
		    
        // Display 1: Butterfly Population by Color Over Time
        display "Butterfly Population" {
            chart "Butterfly Population by Color" type: series {
                data "Black" value: black_population color: #black;
                data "White" value: white_population color: #gray;
                data "Gray" value: gray_population color: #silver;
            }
        }

        // Display 2: Camouflage Effectiveness
        display "Camouflage Effectiveness" {
            chart "Camouflage Effectiveness" type: series {
                data "Effectiveness" value: camouflage_effectiveness color: #green;
            }
        }

        // Display 3: Egg Hatching Success
        display "Egg Hatching Success" {
            chart "Egg Hatching Success" type: pie {
                data "Hatched" value: eggs_hatched color: #yellow;
                data "Failed" value: eggs_failed color: #orange;
            }
        }

        // Display 4: Hunting Success
        display "Hunting Success" {
            chart "Hunting Success" type: series {
                data "Attempts" value: predation_attempts color: #red;
                data "Successes" value: successful_hunts color: #darkred;
            }
        }
        // Display 5: Number of predation attempts and successes by butterfly color
display "Predation Bias Analysis" {
    chart "Butterflies Eaten by Color" type: series {
        data "Black" value: black_hunts color: #black;
        data "White" value: white_hunts color: #gray;
        data "Gray" value: gray_hunts color: #silver;
    }
}


		// Display 6: Proportions of each environmental patch color over time
    display "Environmental Dynamics" {
    chart "Environmental Patch Colors" type: series {
        data "Black Patches" value: black_patches color: #black;
        data "White Patches" value: white_patches color: #gray;
        data "Gray Patches" value: gray_patches color: #silver;
    }
}
    
    }
}
        

            