# syntax=docker/dockerfile:1
### Dev Stage
FROM openmrs/openmrs-core:dev-amazoncorretto-17 AS dev

# Set up the local Maven repository
VOLUME /root/.m2/repository

# Clone the custom module from GitHub
RUN git clone https://github.com/Paradgym/openmrs-module-paradygm.git /tmp/openmrs-module-paradygm
WORKDIR /tmp/openmrs-module-paradygm

# Run mvn clean install to build and install artifacts into the local Maven repo
RUN mvn clean install

RUN git clone https://github.com/Paradgym/openmrs-content-paradygm.git /tmp/openmrs-content-paradygm
WORKDIR /tmp/openmrs-content-paradygm

# Run mvn clean install to build and install artifacts into the local Maven repo
RUN mvn clean install
# Work on the OpenMRS distro
WORKDIR /openmrs_distro
ARG MVN_ARGS_SETTINGS="-s /usr/share/maven/ref/settings-docker.xml -U -P distro"
ARG MVN_ARGS="install"

#Create directory for the required Maven artifact if not present
RUN mkdir -p /root/.m2/repository/org/openmrs/module/paradygm-emr-omod/

# Copy your locally built Maven artifacts into the Docker container
COPY ./maven-repo/org/openmrs/module/paradygm-emr-omod/ /root/.m2/repository/org/openmrs/module/paradygm-emr-omod/

RUN mkdir -p /root/.m2/repository/org/openmrs/content/paradygm-emr-content-package/

COPY ./maven-repo/org/openmrs/content/paradygm-emr-content-package/ /root/.m2/repository/org/openmrs/content/paradygm-emr-content-package/

# Copy the pom.xml and other build files to the working directory
COPY pom.xml ./
COPY distro ./distro/

# Build the OpenMRS distro (this will use the local Maven repository)
RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml if [[ "$MVN_ARGS" != "deploy" || "$(arch)" = "x86_64" ]]; then mvn $MVN_ARGS_SETTINGS $MVN_ARGS; else mvn $MVN_ARGS_SETTINGS install; fi

# Copy necessary artifacts to the final OpenMRS distribution
RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/
RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs-distro.properties /openmrs/distribution/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_modules /openmrs/distribution/openmrs_modules/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_owas /openmrs/distribution/openmrs_owas/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_config /openmrs/distribution/openmrs_config/

# Clean up after copying needed artifacts
RUN mvn $MVN_ARGS_SETTINGS clean

### Run Stage
# Replace 'nightly' with the exact version of openmrs-core built for production (if available)
FROM openmrs/openmrs-core:nightly-amazoncorretto-17

# Do not copy the war if using the correct openmrs-core image version
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/
COPY --from=dev /openmrs/distribution/openmrs-distro.properties /openmrs/distribution/
COPY --from=dev /openmrs/distribution/openmrs_modules /openmrs/distribution/openmrs_modules
COPY --from=dev /openmrs/distribution/openmrs_owas /openmrs/distribution/openmrs_owas
COPY --from=dev /openmrs/distribution/openmrs_config /openmrs/distribution/openmrs_config
