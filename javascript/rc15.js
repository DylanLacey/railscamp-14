define(["modernizr", "prefixfree", "services/typekit", "services/google_analytics", "pages/pay_for_camp"],
  function(modernizr, prefixfree, typekit, googleAnalytics, payForCamp) {

    typekit();
    googleAnalytics();

    // Ghetto router
    if (window.location.pathname == '/pay_for_camp') {
      payForCamp();
    }
  }
);
