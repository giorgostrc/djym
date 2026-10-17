abstract final class Routes {
  static const calendar = '/calendar';
  static const plans = '/plans';
  static const exercises = '/exercises';
  static const settings = '/settings';
  static const newSession = '/session/new';
  static const newExercise = '/exercises/new';
  static const editExercise = '/exercises/:id';

  static String exercise(int id) => '/exercises/$id';
}
