abstract final class Routes {
  static const calendar = '/calendar';
  static const plans = '/plans';
  static const exercises = '/exercises';
  static const settings = '/settings';
  static const workoutSession = '/session/:id';
  static const newExercise = '/exercises/new';
  static const editExercise = '/exercises/:id';

  static String exercise(int id) => '/exercises/$id';

  static String sessionDetail(int id) => '/calendar/sessions/$id';

  static String session(int id, {bool pickExercises = false}) => Uri(
    path: '/session/$id',
    queryParameters: pickExercises ? {'pick': 'true'} : null,
  ).toString();
}
