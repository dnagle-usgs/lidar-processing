/******************************************************************************\
* This file was moved to the attic on 2010-09-13. It was created on an         *
* experimental basis and never came into actual use.                           *
\******************************************************************************/

require, "eaarl.i";

func simulated_annealing(initial_state, max_iterations, max_energy, calculate_energy, neighbor, temperature, acceptance_probability=, show_status=) {
/* DOCUMENT simulated_annealing(initial_state, max_iterations, max_energy,
   calculate_energy, neighbor, temperature, acceptance_probability=,
   show_status=)

   Parameters:
      initial_state: A representation of a state. This can be any value that
         can be stored in a Yorick variable.
      max_iterations: The maximum number of iterations to go through before
         halting.
      max_energy: The maximum energy level that we find acceptable. If the
         state's energy falls below this threshold, the algorithm halts.
      calculate_energy: A function that calculates the energy for a given
         state. It should accept a single parameter, a state value. This state
         value should be homologous to the initial_state value. It should
         return a single value, representing the energy.
      neighbor: A function that picks a neighbor of a given state and returns
         it. It should accept a single parameter, a state value. It should
         return a single value, another state value.
      temperature: A function that calculates the temperature at a given time.
         It should accept a single parameter that represents how far along we
         are in the course of our iterations; this value will be between 0
         (represeting that we just started) and 1 (which represents the last
         iteration). It should return a single value, the temperature.
   
   Options:
      acceptance_probability= A function that returns the probability that the
         current state should be accepted. It takes three arguments: the
         previous state's energy, the current state's energy, and the current
         temperature. It should return a single value between 0 and 1,
         representing probability. A probability of 1 means "always accept", a
         probability of 0 means "always reject". This will default to the
         function default_sa_acceptance_probability.
      show_status= A function that displays some output information, if
         provided. (If not provided, no output is shown.) It should accept a
         single argument, which will be a Yeti has table with these fields: state,
         energy, best_state, best_energy, iteration, max_iterations. It is
         called at the end of each iteration, right before the iteration value
         is increased. This function should display output to the user and
         should not return any values.
*/
   default, acceptance_probability, default_sa_acceptance_probability;

   state = initial_state;
   energy = calculate_energy(state);
   best_state = state;
   best_energy = energy;

   iteration = 1;
   while(iteration <= max_iterations && energy > max_energy) {
      new_state = neighbor(state);
      new_energy = calculate_energy(new_state);
      if(new_energy < best_energy) {
         best_state = new_state;
         best_energy = new_energy;
      }
      if(acceptance_probability(energy, new_energy, temperature(iteration/max_iterations)) > random()) {
         state = new_state;
         energy = new_energy;
      }
      if(!is_void(show_status)) {
         show_status, h_new(
            state=state, energy=energy,
            best_state=best_state, best_energy=best_energy,
            iteration=iteration, max_iterations=max_iterations
         );
      }
      iteration++;
   }
   return best_state;
}

func default_sa_acceptance_probability(energy, new_energy, temperature) {
/* DOCUMENT default_sa_acceptance_probability(energy, new_energy, temperature)
   Used by simulated_annealing. This is the standard acceptance probability
   function used by most simulated annealing algorithms, according to
   Wikipedia. Returns 1 if the new_energy is an improvement. If it's not an
   improvement, returns exp((energy-new_energy)/temperature), provided the
   temperature is positive. If temperature <= 0, then returns 0.
*/
   if(new_energy < energy) {
      return 1;
   } else {
      if(temperature <= 0) {
         return 0;
      } else {
         return exp((energy - new_energy)/temperature);
      }
   }
}
