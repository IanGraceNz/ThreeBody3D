using Printf

"""Construct one named scientific-validation acceptance criterion."""
function validation_criterion(label, value, criterion, passed)
    (
        label=String(label),
        value,
        criterion=String(criterion),
        passed=Bool(passed),
    )
end

"""
    validate_acceptance_criteria(title, criteria)

Print a common validation-acceptance table and throw an error naming every
failed criterion. A standalone validation script therefore exits nonzero when
its declared scientific limits are not satisfied.
"""
function validate_acceptance_criteria(title, criteria)
    isempty(criteria) && throw(ArgumentError("At least one acceptance criterion is required."))

    println()
    println(title)
    for result in criteria
        status = result.passed ? "PASS" : "FAIL"
        value = result.value isa AbstractFloat ? @sprintf("%.3e", result.value) : string(result.value)
        println(
            "  ",
            rpad(result.label, 54),
            rpad(status, 6),
            "value=", lpad(value, 10),
            "  criterion ", result.criterion,
        )
    end

    failures = filter(result -> !result.passed, criteria)
    isempty(failures) || error(
        "Validation acceptance criteria failed: " *
        join((result.label for result in failures), "; "),
    )

    true
end
