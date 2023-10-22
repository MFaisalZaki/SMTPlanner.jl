
@testset "linear encodings" begin

    problem_domain   = load_domain(IPCInstancesRepo, "ipc-2002-rovers-strips-automatic");
    problem_instance = load_problem(IPCInstancesRepo, "ipc-2002-rovers-strips-automatic", 1);

    state = initstate(problem_domain, problem_instance);
    grounded_actions = ground_problem_actions(problem_domain, state);

    # TODO: Add test cases for the linear encodings.
    @test 1 == 1
end
