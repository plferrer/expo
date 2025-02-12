/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include <gtest/gtest.h>
#include <ABI46_0_0React/ABI46_0_0renderer/core/DynamicPropsUtilities.h>

using namespace folly;
using namespace ABI46_0_0facebook::ABI46_0_0React;

/*
  Tests that verify expected behaviour from `folly::dynamic::merge_patch`.
  `merge_patch` is used for props forwarding on Android to enable Background
  Executor and will be removed once JNI layer is reimplmeneted.
 */
TEST(DynamicPropsUtilitiesTest, handleNestedObjects) {
  dynamic map1 = dynamic::object;
  map1["style"] = dynamic::object("backgroundColor", "red");

  dynamic map2 = dynamic::object;
  map2["style"] = dynamic::object("backgroundColor", "blue")("color", "black");
  map2["height"] = 100;

  auto result = mergeDynamicProps(map1, map2);

  ABI46_0_0EXPECT_TRUE(result["style"].isObject());
  ABI46_0_0EXPECT_TRUE(result["style"]["backgroundColor"].isString());
  ABI46_0_0EXPECT_TRUE(result["style"]["color"].isString());
  ABI46_0_0EXPECT_TRUE(result["height"].isInt());

  ABI46_0_0EXPECT_EQ(result["style"]["backgroundColor"].asString(), "blue");
  ABI46_0_0EXPECT_EQ(result["style"]["color"], "black");
  ABI46_0_0EXPECT_EQ(result["height"], 100);
}

TEST(DynamicPropsUtilitiesTest, handleEmptyObject) {
  dynamic map1 = dynamic::object;

  dynamic map2 = dynamic::object;
  map2["height"] = 100;

  auto result = mergeDynamicProps(map1, map2);

  ABI46_0_0EXPECT_TRUE(result["height"].isInt());
  ABI46_0_0EXPECT_EQ(result["height"], 100);

  result = mergeDynamicProps(map1, map2);

  ABI46_0_0EXPECT_TRUE(result["height"].isInt());
  ABI46_0_0EXPECT_EQ(result["height"], 100);
}

TEST(DynamicPropsUtilitiesTest, handleNull) {
  dynamic map1 = dynamic::object;
  map1["height"] = 100;

  dynamic map2 = dynamic::object;
  map2["height"] = nullptr;

  auto result = mergeDynamicProps(map1, map2);

  ABI46_0_0EXPECT_TRUE(result["height"].isNull());
}
