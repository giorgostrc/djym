abstract final class Routes {
  static const calendar = '/calendar';
  static const plans = '/plans';
  static const exercises = '/exercises';
  static const settings = '/settings';
  static const workoutSession = '/session/:id';
  static const newExercise = '/exercises/new';
  static const editExercise = '/exercises/:id/edit';
  static const newPlan = '/plans/new';
  static const editPlan = '/plans/:id';
  static const subscriptions = '/calendar/subscriptions';
  static const newSubscription = '/subscriptions/new';
  static const editSubscription = '/subscriptions/:id';

  static String exercise(int id) => '/exercises/$id';

  static String exerciseEdit(int id) => '/exercises/$id/edit';

  static String exerciseWorkout(int exerciseId, int sessionId) =>
      '/exercises/$exerciseId/sessions/$sessionId';

  static String sessionDetail(int id) => '/calendar/sessions/$id';

  static String plan(int id) => '/plans/$id';

  static String subscription(int id) => '/subscriptions/$id';

  static String renewSubscription(int id) => '$newSubscription?renew=$id';

  static String session(int id, {bool pickExercises = false}) => Uri(
    path: '/session/$id',
    queryParameters: pickExercises ? {'pick': 'true'} : null,
  ).toString();
}
